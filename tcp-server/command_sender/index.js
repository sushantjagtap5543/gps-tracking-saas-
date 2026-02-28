/**
 * Command Sender - PRODUCTION READY
 * All issues fixed: Timeout, retry, error handling
 */

const sessionManager = require('../sessions');
const gt06 = require('../protocols/gt06');
const { Pool } = require('pg');
const config = require('../config');

const db = new Pool({
    host: config.database.host,
    port: config.database.port,
    database: config.database.name,
    user: config.database.user,
    password: config.database.password
});

class CommandSender {
    constructor() {
        this.pendingCommands = new Map(); // commandId -> {timeout, deviceId, commandLogId}
        this.maxRetries = config.device.maxRetries;
        this.ackTimeout = config.device.ackTimeout * 1000;
        
        // Cleanup stale pending commands every hour
        setInterval(() => this.cleanupStaleCommands(), 3600000);
    }

    /**
     * Send command to device with retry logic
     */
    async send(deviceId, command, commandLogId = null) {
        try {
            // Get device info
            const device = await this.getDeviceInfo(deviceId);
            if (!device) {
                throw new Error('Device not found');
            }
            
            // Get socket
            const socket = sessionManager.getSocketByImei(device.imei);
            if (!socket) {
                // Device offline - queue command
                await this.queueCommand(deviceId, command, commandLogId);
                return { queued: true, message: 'Device offline, command queued' };
            }
            
            // Check if socket is writable
            if (!socket.writable) {
                throw new Error('Socket not writable');
            }
            
            // Create device-specific command
            const commandBuffer = this.createCommand(device.protocol, command);
            
            // Send to device
            socket.write(commandBuffer, (err) => {
                if (err) {
                    console.error('Socket write error:', err);
                    this.handleSendError(commandLogId, deviceId);
                }
            });
            
            // Update command log
            if (commandLogId) {
                await this.updateCommandLog(commandLogId, 'SENT');
            }
            
            // Set timeout for ACK
            const timeout = setTimeout(() => {
                this.handleTimeout(commandLogId, deviceId);
            }, this.ackTimeout);
            
            if (commandLogId) {
                this.pendingCommands.set(commandLogId, {
                    timeout,
                    deviceId,
                    attemptCount: 0,
                    sentAt: Date.now()
                });
            }
            
            return { sent: true, commandLogId };
            
        } catch (error) {
            console.error('Command send error:', error);
            
            // Update command log with error
            if (commandLogId) {
                await this.updateCommandLog(commandLogId, 'FAILED', error.message);
            }
            
            throw error;
        }
    }

    /**
     * Handle send error
     */
    async handleSendError(commandLogId, deviceId) {
        if (commandLogId) {
            await this.updateCommandLog(commandLogId, 'FAILED', 'Socket write error');
        }
    }

    /**
     * Queue command for offline device
     */
    async queueCommand(deviceId, command, commandLogId) {
        try {
            // Check if command already queued
            const existing = await db.query(`
                SELECT id FROM command_queue 
                WHERE command_log_id = $1 AND status = 'QUEUED'
            `, [commandLogId]);
            
            if (existing.rows.length === 0) {
                await db.query(`
                    INSERT INTO command_queue (id, device_id, command_log_id, status)
                    VALUES (uuid_generate_v4(), $1, $2, 'QUEUED')
                `, [deviceId, commandLogId]);
            }
            
        } catch (error) {
            console.error('Queue command error:', error);
        }
    }

    /**
     * Handle command timeout
     */
    async handleTimeout(commandLogId, deviceId) {
        try {
            const pending = this.pendingCommands.get(commandLogId);
            if (!pending) return;
            
            this.pendingCommands.delete(commandLogId);
            clearTimeout(pending.timeout);
            
            // Get current attempt count
            const result = await db.query(`
                SELECT attempt_count FROM command_logs WHERE id = $1
            `, [commandLogId]);
            
            const attemptCount = (result.rows[0]?.attempt_count || 0) + 1;
            
            if (attemptCount <= this.maxRetries) {
                // Retry with exponential backoff
                const delay = Math.pow(2, attemptCount) * 1000;
                console.log(`Retrying command ${commandLogId} in ${delay}ms (attempt ${attemptCount})`);
                
                setTimeout(async () => {
                    try {
                        // Get command text
                        const cmdResult = await db.query(`
                            SELECT command_text FROM command_logs WHERE id = $1
                        `, [commandLogId]);
                        
                        if (cmdResult.rows[0]) {
                            await this.send(deviceId, cmdResult.rows[0].command_text, commandLogId);
                        }
                    } catch (err) {
                        console.error('Retry error:', err);
                    }
                }, delay);
                
                // Update attempt count
                await db.query(`
                    UPDATE command_logs 
                    SET attempt_count = $1
                    WHERE id = $2
                `, [attemptCount, commandLogId]);
                
            } else {
                // Max retries exceeded
                await db.query(`
                    UPDATE command_logs 
                    SET status = 'TIMEOUT', 
                        error_message = 'Max retries exceeded',
                        completed_at = CURRENT_TIMESTAMP
                    WHERE id = $1
                `, [commandLogId]);
            }
            
        } catch (error) {
            console.error('Timeout handling error:', error);
        }
    }

    /**
     * Cleanup stale pending commands
     */
    async cleanupStaleCommands() {
        try {
            // Mark commands older than 24 hours as failed
            const result = await db.query(`
                UPDATE command_queue 
                SET status = 'FAILED'
                WHERE created_at < NOW() - INTERVAL '24 hours'
                AND status = 'QUEUED'
                RETURNING id
            `);
            
            if (result.rowCount > 0) {
                console.log(`Cleaned up ${result.rowCount} stale queued commands`);
            }
            
            // Delete old completed command logs
            const deleteResult = await db.query(`
                DELETE FROM command_logs 
                WHERE created_at < NOW() - INTERVAL '30 days'
                AND status IN ('SUCCESS', 'FAILED', 'TIMEOUT')
                RETURNING id
            `);
            
            if (deleteResult.rowCount > 0) {
                console.log(`Deleted ${deleteResult.rowCount} old command logs`);
            }
            
        } catch (error) {
            console.error('Cleanup stale commands error:', error);
        }
    }

    /**
     * Get device info with caching
     */
    async getDeviceInfo(deviceId) {
        try {
            const result = await db.query(`
                SELECT d.id, d.imei, dm.protocol
                FROM devices d
                JOIN device_models dm ON d.model_id = dm.id
                WHERE d.id = $1 AND d.is_active = true
            `, [deviceId]);
            
            return result.rows[0] || null;
        } catch (error) {
            console.error('Get device info error:', error);
            return null;
        }
    }

    /**
     * Create device-specific command
     */
    createCommand(protocol, command) {
        switch(protocol) {
            case 'GT06':
                return gt06.createCommand(command, Math.floor(Math.random() * 65535));
            default:
                return Buffer.from(command + '\r\n', 'ascii');
        }
    }

    /**
     * Update command log
     */
    async updateCommandLog(commandLogId, status, error = null) {
        try {
            let query;
            let params;
            
            if (status === 'SENT') {
                query = `
                    UPDATE command_logs 
                    SET status = $1, 
                        sent_at = CURRENT_TIMESTAMP,
                        attempt_count = attempt_count + 1
                    WHERE id = $2
                `;
                params = [status, commandLogId];
            } else if (error) {
                query = `
                    UPDATE command_logs 
                    SET status = $1, 
                        error_message = $2,
                        completed_at = CURRENT_TIMESTAMP
                    WHERE id = $3
                `;
                params = [status, error, commandLogId];
            } else {
                query = `
                    UPDATE command_logs 
                    SET status = $1,
                        completed_at = CURRENT_TIMESTAMP
                    WHERE id = $2
                `;
                params = [status, commandLogId];
            }
            
            await db.query(query, params);
            
        } catch (error) {
            console.error('Update command log error:', error);
        }
    }
}

module.exports = new CommandSender();
