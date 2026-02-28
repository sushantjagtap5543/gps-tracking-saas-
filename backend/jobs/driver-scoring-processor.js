const AIScoringService = require('../services/ai-scoring.service');
const pool = new require('pg').Pool({ connectionString: process.env.DATABASE_URL });

setInterval(async () => {
  const users = await pool.query('SELECT id FROM users WHERE role_id = (SELECT id FROM roles WHERE name = \'DRIVER\')');
  for (const user of users.rows) {
    const service = new AIScoringService(pool);
    await service.calculateScore(user.id, new Date(Date.now() - 30*24*3600000), new Date());
  }
}, 86400000); // Daily
