require('dotenv').config();

module.exports = {
  database: {
    host: process.env.DB_HOST || 'postgres',
    port: parseInt(process.env.DB_PORT) || 5432,
    name: process.env.DB_NAME || 'gps_tracking',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    poolSize: parseInt(process.env.DB_POOL_SIZE) || 100,
    idleTimeout: 30000,
    connectionTimeout: 5000
  },
  redis: {
    host: process.env.REDIS_HOST || 'redis',
    port: parseInt(process.env.REDIS_PORT) || 6379,
    password: process.env.REDIS_PASSWORD || '',
    keyPrefix: 'gps:',
    maxMemory: process.env.REDIS_MAX_MEMORY || '2gb',
    evictionPolicy: process.env.REDIS_EVICTION_POLICY || 'allkeys-lru'
  },
  server: {
    port: 5023,
    host: '0.0.0.0',
    maxConnections: parseInt(process.env.MAX_CONNECTIONS) || 1000,
    backlog: 511
  },
  device: {
    heartbeatTimeout: parseInt(process.env.HEARTBEAT_TIMEOUT) || 300,
    offlineTimeout: parseInt(process.env.OFFLINE_TIMEOUT) || 600,
    maxRetries: parseInt(process.env.MAX_RETRIES) || 3,
    ackTimeout: parseInt(process.env.ACK_TIMEOUT) || 30
  },
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    file: process.env.LOG_FILE || 'logs/tcp-server.log',
    maxSize: 10485760,
    maxFiles: 10
  },
  limits: {
    packetRate: parseInt(process.env.PACKET_RATE_LIMIT) || 100,
    dataRate: parseInt(process.env.DATA_RATE_LIMIT) || 102400
  }
};
