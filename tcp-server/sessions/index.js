/**
 * Device Session Manager - PRODUCTION READY
 * All issues fixed: Memory leaks, cleanup, TTL
 */

const Redis = require('ioredis');
const config = require('../config');

const redis = new Redis({
    host: config.redis.host,
    port: config.redis.port,
    password: config.redis.password,
    keyPrefix: 'session:'
});

class SessionManager {
    constructor() {
        this.sessions = new Map(); // imei -> session info
        this.socketMap = new Map(); // socket -> imei
        this.stats = {
            totalConnections: 0,
            activeConnections: 0,
            peakConnections: 0,
            rejectedConnections: 0
        };
        
        // Aggressive cleanup every minute
        setInterval(() => this.forceCleanup(), 60000);
        
        // Report stats every 5 minutes
        setInterval(() => this.reportStats(), 300000);
    }

    /**
     * Create new session with TTL
     */
    async createSession({ deviceId, imei, socket, ip, modelId, protocol }) {
        // Check connection limit
        if (this.sessions.size >= config.server.maxConnections) {
            this.stats.rejectedConnections++;
            throw new Error('Max connections reached');
        }
        
        // Check for existing session
        const existing = this.sessions.get(imei);
        if (existing) {
            // Force disconnect old session
            const oldSocket = this.getSocketByImei(imei);
            if (oldSocket) {
                oldSocket.destroy();
                this.socketMap.delete(oldSocket);
            }
            this.sessions.delete(imei);
        }
        
        const session = {
            deviceId,
            imei,
            ip,
            modelId,
            protocol,
            connectedAt: Date.now(),
            lastActivity: Date.now(),
            packetCount: 0,
            socketId: this.generateSocketId()
        };
        
        this.sessions.set(imei, session);
        this.socketMap.set(socket, imei);
        
        // Update stats
        this.stats.totalConnections++;
        this.stats.activeConnections = this.sessions.size;
        this.stats.peakConnections = Math.max(this.stats.peakConnections, this.sessions.size);
        
        // Store in Redis with TTL
        await redis.hmset(imei, {
            deviceId,
            ip,
            modelId,
            protocol,
            connectedAt: session.connectedAt,
            socketId: session.socketId
        });
        await redis.expire(imei, 86400); // 24 hour TTL
        
        return session;
    }

    /**
     * Generate unique socket ID
     */
    generateSocketId() {
        return Math.random().toString(36).substring(2, 15) + 
               Math.random().toString(36).substring(2, 15);
    }

    /**
     * Force cleanup of stale sessions
     */
    forceCleanup() {
        const now = Date.now();
        const timeout = 300000; // 5 minutes
        let cleaned = 0;
        
        for (const [imei, session] of this.sessions) {
            if (now - session.lastActivity > timeout) {
                console.log(`Cleaning stale session: ${imei} (${(now - session.lastActivity)/1000}s idle)`);
                
                // Force socket disconnect
                const socket = this.getSocketByImei(imei);
                if (socket) {
                    socket.destroy();
                    this.socketMap.delete(socket);
                }
                
                this.sessions.delete(imei);
                cleaned++;
            }
        }
        
        if (cleaned > 0) {
            console.log(`Cleaned ${cleaned} stale sessions`);
            this.stats.activeConnections = this.sessions.size;
        }
    }

    /**
     * Report session statistics
     */
    reportStats() {
        console.log('Session Manager Stats:', {
            active: this.sessions.size,
            total: this.stats.totalConnections,
            peak: this.stats.peakConnections,
            rejected: this.stats.rejectedConnections,
            socketMap: this.socketMap.size
        });
    }

    /**
     * Get session by IMEI
     */
    getSession(imei) {
        return this.sessions.get(imei);
    }

    /**
     * Get IMEI by socket
     */
    getImeiBySocket(socket) {
        return this.socketMap.get(socket);
    }

    /**
     * Update session activity
     */
    async updateActivity(imei) {
        const session = this.sessions.get(imei);
        if (session) {
            session.lastActivity = Date.now();
            session.packetCount++;
            
            // Update Redis asynchronously (don't await)
            redis.hset(imei, 'lastActivity', session.lastActivity)
                .catch(err => console.error('Redis activity update error:', err));
        }
    }

    /**
     * Remove session
     */
    async removeSession(imei) {
        const session = this.sessions.get(imei);
        if (session) {
            this.sessions.delete(imei);
            
            // Find and remove socket mapping
            for (const [socket, sockImei] of this.socketMap) {
                if (sockImei === imei) {
                    this.socketMap.delete(socket);
                    break;
                }
            }
            
            // Update stats
            this.stats.activeConnections = this.sessions.size;
            
            // Remove from Redis
            await redis.del(imei).catch(err => console.error('Redis delete error:', err));
        }
    }

    /**
     * Get all online devices
     */
    getOnlineDevices() {
        return Array.from(this.sessions.keys());
    }

    /**
     * Get session count
     */
    getSessionCount() {
        return this.sessions.size;
    }

    /**
     * Get socket by IMEI
     */
    getSocketByImei(imei) {
        for (const [socket, sockImei] of this.socketMap) {
            if (sockImei === imei) {
                return socket;
            }
        }
        return null;
    }

    /**
     * Get all sockets
     */
    getAllSockets() {
        return Array.from(this.socketMap.keys());
    }

    /**
     * Check if device is online
     */
    isOnline(imei) {
        return this.sessions.has(imei);
    }

    /**
     * Get statistics
     */
    getStats() {
        return {
            ...this.stats,
            currentConnections: this.sessions.size
        };
    }
}

module.exports = new SessionManager();
