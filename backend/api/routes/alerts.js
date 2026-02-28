const express = require('express');
const router = express.Router();
const AlertService = require('../../services/alert.service');
const pool = new require('pg').Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

router.get('/', async (req, res) => {
  const service = new AlertService(pool, redis);
  const alerts = await service.getAlerts(req.query.deviceId);
  res.json(alerts);
});

module.exports = router;
