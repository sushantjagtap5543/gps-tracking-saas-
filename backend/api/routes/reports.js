const express = require('express');
const router = express.Router();
const ReportService = require('../../services/report.service');
const pool = new require('pg').Pool({ connectionString: process.env.DATABASE_URL });

router.get('/kpis', async (req, res) => {
  const service = new ReportService(pool);
  const kpis = await service.getKpis(req.query.deviceId, req.query.start, req.query.end);
  res.json(kpis);
});

module.exports = router;
