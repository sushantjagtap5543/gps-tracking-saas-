class ResellerService {
  constructor(pool) {
    this.pool = pool;
  }

  async createReseller(userId, subdomain) {
    await this.pool.query('INSERT INTO resellers (user_id, subdomain) VALUES ($1, $2)', [userId, subdomain]);
  }

  async calculateCommission(resellerId) {
    // Logic from document
  }
}

module.exports = ResellerService;
