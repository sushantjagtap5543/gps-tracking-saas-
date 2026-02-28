const Redis = require('ioredis');
const AlertService = require('../services/alert.service');
const redis = new Redis(process.env.REDIS_URL);
const pool = new require('pg').Pool({ connectionString: process.env.DATABASE_URL });

async function processAlerts() {
  const pubsub = redis.duplicate();
  pubsub.subscribe('gps_updates');
  pubsub.on('message', async (channel, message) => {
    if (channel === 'gps_updates') {
      const { deviceId, gpsData } = JSON.parse(message);
      const service = new AlertService(pool, redis);
      await service.evaluate(deviceId, gpsData);
    }
  });
}

processAlerts();
