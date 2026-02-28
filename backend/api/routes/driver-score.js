const express = require('express');
const router = express.Router();
const AIScoringService = require('../../services/ai-scoring.service');
const pool = new require('pg').Pool({ connectionString: process.env.DATABASE_URL });

router.get('/', async (req, res) => {
  const service = new AIScoringService(pool);
  const score = await service.calculateScore(req.query.userId, req.query.start, req.query.end);
  res.json({ score });
});

module.exports = router;
