const express = require('express');
const router = express.Router();
const LiveMapService = require('../../services/live-map.service');
const pool = new require('pg').Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

router.get('/live/:deviceId', async (req, res) => {
  const service = new LiveMapService(pool, redis);
  const location = await service.getLiveLocation(req.params.deviceId);
  res.json(location);
});

module.exports = router;
