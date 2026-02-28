const Redis = require('ioredis');
const TripService = require('../services/trip.service');
const redis = new Redis(process.env.REDIS_URL);
const pool = new require('pg').Pool({ connectionString: process.env.DATABASE_URL });

async function processTrips() {
  const pubsub = redis.duplicate();
  pubsub.subscribe('gps_updates');
  pubsub.on('message', async (channel, message) => {
    if (channel === 'gps_updates') {
      const { deviceId, gpsData } = JSON.parse(message);
      const service = new TripService(pool, redis);
      await service.processGpsPoint(deviceId, gpsData);
    }
  });
}

processTrips();
