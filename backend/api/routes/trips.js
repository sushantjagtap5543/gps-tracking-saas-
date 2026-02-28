const express = require('express');
const router = express.Router();
const TripService = require('../../services/trip.service');
const pool = new require('pg').Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

router.get('/', async (req, res) => {
  const service = new TripService(pool, redis);
  // Get trips logic
  res.json({ trips: [] }); // Placeholder
});

module.exports = router;
