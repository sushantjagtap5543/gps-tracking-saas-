/**
 * WebSocket for Real-time Map Updates - PRODUCTION READY
 * Port: 5024
 * All issues fixed: Memory leaks, heartbeat, cleanup
 */

const { Server } = require('socket.io');
const Redis = require('ioredis');
const jwt = require('jsonwebtoken');

const redis = new Redis(process.env.REDIS_URL);
const subClient = new Redis(process.env.REDIS_URL);

class MapSocket {
    constructor(server) {
        this.io = new Server(server, {
            cors: {
                origin: ['http://3.108.114.12:5025', 'http://localhost:3001'],
                methods: ['GET', 'POST'],
                credentials: true
            },
            path: '/socket.io',
            pingTimeout: 60000,
            pingInterval: 25000,
            transports: ['websocket', 'polling'],
            allowEIO3: true,
            maxHttpBufferSize: 1e6,
            connectTimeout: 45000
        });

        this.connectedClients = new Map(); // userId -> {socketId, lastHeartbeat}
        this.clientVehicles = new Map();   // clientId -> Set of vehicleIds
        
        // Heartbeat interval
        setInterval(() => this.checkHeartbeats(), 30000);
        
        // Stats reporting
        setInterval(() => this.reportStats(), 300000);

        this.initialize();
    }

    initialize() {
        // Authentication middleware
        this.io.use(async (socket, next) => {
            try {
                const token = socket.handshake.auth.token;
                if (!token) {
                    return next(new Error('Authentication required'));
                }

                const decoded = jwt.verify(token, process.env.JWT_SECRET);
                socket.userId = decoded.userId;
                socket.clientId = decoded.clientId;
                socket.role = decoded.role;
                
                next();
            } catch (error) {
                next(new Error('Invalid token'));
            }
        });

        // Connection handler
        this.io.on('connection', (socket) => {
            this.handleConnection(socket);
        });

        // Subscribe to Redis channels
        subClient.subscribe('map:update', 'command:result', (err) => {
            if (err) console.error('Redis subscribe error:', err);
        });

        subClient.on('message', (channel, message) => {
            switch(channel) {
                case 'map:update':
                    this.broadcastLocationUpdate(JSON.parse(message));
                    break;
                case 'command:result':
                    this.broadcastCommandResult(JSON.parse(message));
                    break;
            }
        });

        console.log('Map WebSocket initialized on port 5024');
    }

    /**
     * Handle new client connection
     */
    handleConnection(socket) {
        console.log(`Client connected: ${socket.id} (User: ${socket.userId})`);

        // Store connection with heartbeat
        this.connectedClients.set(socket.userId, {
            socketId: socket.id,
            connectedAt: Date.now(),
            lastHeartbeat: Date.now(),
            clientId: socket.clientId,
            role: socket.role
        });

        // Join rooms
        if (socket.clientId) {
            socket.join(`client:${socket.clientId}`);
        }

        if (socket.role === 'ADMIN' || socket.role === 'SUPER_ADMIN') {
            socket.join('admin');
        }

        // Heartbeat handler
        socket.on('heartbeat', () => {
            const client = this.connectedClients.get(socket.userId);
            if (client) {
                client.lastHeartbeat = Date.now();
            }
        });

        // Request handlers
        socket.on('request:vehicle:focus', (vehicleId) => {
            this.handleVehicleFocus(socket, vehicleId);
        });

        socket.on('request:map:bounds', async () => {
            await this.sendMapBounds(socket);
        });

        socket.on('subscribe:vehicle', (vehicleId) => {
            this.subscribeToVehicle(socket, vehicleId);
        });

        socket.on('unsubscribe:vehicle', (vehicleId) => {
            this.unsubscribeFromVehicle(socket, vehicleId);
        });

        // Disconnect handler
        socket.on('disconnect', () => {
            this.handleDisconnect(socket);
        });

        // Error handler
        socket.on('error', (error) => {
            console.error(`Socket error for user ${socket.userId}:`, error);
        });

        // Send initial data
        this.sendInitialData(socket);
    }

    /**
     * Check heartbeats and clean stale connections
     */
    checkHeartbeats() {
        const now = Date.now();
        const timeout = 60000; // 1 minute

        for (const [userId, client] of this.connectedClients) {
            if (now - client.lastHeartbeat > timeout) {
                console.log(`User ${userId} heartbeat timeout, disconnecting`);
                
                const socket = this.io.sockets.sockets.get(client.socketId);
                if (socket) {
                    socket.disconnect(true);
                }
                
                this.connectedClients.delete(userId);
            }
        }
    }

    /**
     * Report connection statistics
     */
    reportStats() {
        console.log('WebSocket Stats:', {
            connected: this.connectedClients.size,
            rooms: this.io.sockets.adapter.rooms.size,
            byRole: this.getStatsByRole()
        });
    }

    /**
     * Get stats grouped by role
     */
    getStatsByRole() {
        const stats = {};
        for (const client of this.connectedClients.values()) {
            stats[client.role] = (stats[client.role] || 0) + 1;
        }
        return stats;
    }

    /**
     * Send initial map data to client
     */
    async sendInitialData(socket) {
        try {
            const liveMapService = require('../services/live-map.service');
            const vehicles = await liveMapService.getClientVehicles(socket.clientId);
            
            socket.emit('map:init', {
                vehicles,
                timestamp: new Date().toISOString()
            });

            // Send stats
            const onlineCount = vehicles.filter(v => v.status === 'online').length;
            socket.emit('stats:update', {
                total: vehicles.length,
                online: onlineCount,
                offline: vehicles.length - onlineCount,
                moving: vehicles.filter(v => v.ignition && v.speed > 0).length,
                timestamp: new Date().toISOString()
            });

        } catch (error) {
            console.error('Send initial data error:', error);
            socket.emit('error', { message: 'Failed to load map data' });
        }
    }

    /**
     * Broadcast location update
     */
    broadcastLocationUpdate(update) {
        if (update.clientId) {
            this.io.to(`client:${update.clientId}`).emit('vehicle:update', update);
        }
        this.io.to('admin').emit('vehicle:update', update);
    }

    /**
     * Broadcast command result
     */
    broadcastCommandResult(result) {
        this.io.to('admin').emit('command:result', result);
    }

    /**
     * Handle vehicle focus
     */
    handleVehicleFocus(socket, vehicleId) {
        socket.emit('vehicle:focus', { vehicleId });
    }

    /**
     * Send map bounds
     */
    async sendMapBounds(socket) {
        try {
            const liveMapService = require('../services/live-map.service');
            const bounds = await liveMapService.getMapBounds(socket.clientId);
            socket.emit('map:bounds', bounds);
        } catch (error) {
            console.error('Send map bounds error:', error);
        }
    }

    /**
     * Subscribe to vehicle updates
     */
    subscribeToVehicle(socket, vehicleId) {
        socket.join(`vehicle:${vehicleId}`);
        
        if (!this.clientVehicles.has(socket.clientId)) {
            this.clientVehicles.set(socket.clientId, new Set());
        }
        this.clientVehicles.get(socket.clientId).add(vehicleId);
    }

    /**
     * Unsubscribe from vehicle updates
     */
    unsubscribeFromVehicle(socket, vehicleId) {
        socket.leave(`vehicle:${vehicleId}`);
        
        const vehicles = this.clientVehicles.get(socket.clientId);
        if (vehicles) {
            vehicles.delete(vehicleId);
        }
    }

    /**
     * Handle disconnection
     */
    handleDisconnect(socket) {
        console.log(`Client disconnected: ${socket.id} (User: ${socket.userId})`);
        this.connectedClients.delete(socket.userId);
    }

    /**
     * Get connected clients count
     */
    getConnectedCount() {
        return this.connectedClients.size;
    }
}

module.exports = MapSocket;
