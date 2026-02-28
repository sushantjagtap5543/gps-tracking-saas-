/**
 * Command ACK Handler - PRODUCTION READY
 */

const Redis = require('ioredis');
const { Pool } = require('pg');
const config = require('../config');

const redis = new Redis({
    host: config.redis.host,
    port: config.redis.port,
    password: config.redis.password
});

const pool = new Pool({
    host: config.database.host,
    port: config.database.port,
    database: config.database.name,
    user: config.database.user,
    password: config.database.password
});

class AckHandler {
    constructor() {
        this.successPatterns = ['ok', 'success', 'done', '1', 'ack'];
    }

    /**
     * Handle command response from device
     */
    async handle(imei, response) {
        try {
            // Find pending command for this device
            const pendingCmd = await pool.query(`
                SELECT cq.*, cl.id as command_log_id, cl.attempt_count
                FROM command_queue cq
                JOIN command_logs cl ON cq.command_log_id = cl.id
                JOIN devices d ON cq.device_id = d.id
                WHERE d.imei = $1 
                AND cq.status = 'SENT'
                ORDER BY cq.created_at DESC
                LIMIT 1
            `, [imei]);

            if (pendingCmd.rows.length === 0) {
                console.log(`No pending command for ${imei}`);
                return;
            }

            const cmd = pendingCmd.rows[0];

            // Check if response indicates success
            const success = this.isSuccessResponse(response);

            // Update command log
            await pool.query(`
                UPDATE command_logs 
                SET status = $1,
                    ack_received = true,
                    ack_data = $2,
                    completed_at = CURRENT_TIMESTAMP,
                    device_response_time_ms = EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - sent_at)) * 1000
                WHERE id = $3
            `, [success ? 'SUCCESS' : 'FAILED', JSON.stringify(response), cmd.command_log_id]);

            // Remove from queue
            await pool.query(`
                DELETE FROM command_queue 
                WHERE command_log_id = $1
            `, [cmd.command_log_id]);

            // Publish result
            await redis.publish('command:result', JSON.stringify({
                commandLogId: cmd.command_log_id,
                success,
                response,
                attemptCount: cmd.attempt_count,
                timestamp: new Date()
            }));

            console.log(`Command ${cmd.command_log_id} completed with ${success ? 'SUCCESS' : 'FAILURE'}`);

        } catch (error) {
            console.error('ACK handling error:', error);
        }
    }

    /**
     * Check if response indicates success
     */
    isSuccessResponse(response) {
        if (response.type === 'COMMAND_RESPONSE') {
            const data = response.data?.toLowerCase() || '';
            return this.successPatterns.some(pattern => data.includes(pattern));
        }
        return false;
    }
}

module.exports = new AckHandler();
