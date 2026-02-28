const express = require('express');
const router = express.Router();
const CommandService = require('../../services/command.service');
const pool = new require('pg').Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

router.post('/', async (req, res) => {
  const service = new CommandService(pool, redis);
  const result = await service.sendCommand(req.body.deviceId, req.body.command, req.body.parameters);
  res.json(result);
});

module.exports = router;
