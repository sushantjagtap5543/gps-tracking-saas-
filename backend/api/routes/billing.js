const express = require('express');
const router = express.Router();
const BillingService = require('../../services/billing.service');
const pool = new require('pg').Pool({ connectionString: process.env.DATABASE_URL });

router.post('/subscription', async (req, res) => {
  const service = new BillingService(pool);
  const sub = await service.createSubscription(req.body.userId, req.body.planId);
  res.json(sub);
});

module.exports = router;
