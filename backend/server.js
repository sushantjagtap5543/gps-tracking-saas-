require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const Redis = require('ioredis');
const uuid = require('uuid');
const logger = require('winston').createLogger({ level: 'info' });

const app = express();
app.use(express.json());

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

const PORT = process.env.BACKEND_INTERNAL_PORT || 3000;

// Services (compiled from documents)
const CommandService = require('./services/command.service');
const AlertService = require('./services/alert.service');
// ... require all

// Routes (from file 18, 19, etc.)
app.post('/api/commands', async (req, res) => {
  try {
    const service = new CommandService(pool, redis);
    const result = await service.sendCommand(req.body.deviceId, req.body.command);
    res.json(result);
  } catch (err) {
    logger.error(err);
    res.status(500).json({ error: err.message });
  }
});

// Add routes for alerts, map, trips, reports, billing, reseller, ai

app.listen(PORT, '0.0.0.0', () => logger.info(`Backend on internal ${PORT}`));
