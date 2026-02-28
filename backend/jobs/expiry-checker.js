const BillingService = require('../services/billing.service');
const pool = new require('pg').Pool({ connectionString: process.env.DATABASE_URL });

setInterval(async () => {
  const service = new BillingService(pool);
  await service.checkExpiry();
}, 3600000); // Hourly
