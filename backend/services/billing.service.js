const Stripe = require('stripe');
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

class BillingService {
  constructor(pool) {
    this.pool = pool;
  }

  async createSubscription(userId, planId) {
    const plan = await this.pool.query('SELECT * FROM plans WHERE id = $1', [planId]);
    if (!plan.rows[0]) throw new Error('Plan not found');

    const sub = await stripe.subscriptions.create({ /* ... */ });
    await this.pool.query('INSERT INTO subscriptions (user_id, plan_id, start_date, end_date) VALUES ($1, $2, NOW(), NOW() + INTERVAL '1 MONTH')', [userId, planId]);
    return sub;
  }

  async checkExpiry() {
    await this.pool.query('UPDATE subscriptions SET status = 'EXPIRED' WHERE end_date < NOW()');
  }
}

module.exports = BillingService;
