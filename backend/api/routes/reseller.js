const express = require('express');
const router = express.Router();
const ResellerService = require('../../services/reseller.service');
const pool = new require('pg').Pool({ connectionString: process.env.DATABASE_URL });

router.post('/', async (req, res) => {
  const service = new ResellerService(pool);
  await service.createReseller(req.body.userId, req.body.subdomain);
  res.json({ success: true });
});

module.exports = router;
