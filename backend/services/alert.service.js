class AlertService {
  constructor(pool, redis) {
    this.pool = pool;
    this.redis = redis;
  }

  async evaluate(deviceId, gpsData) {
    const rules = await this.pool.query('SELECT * FROM alert_rules');
    const triggered = [];

    for (const rule of rules.rows) {
      const cacheKey = `alert:cooldown:${deviceId}:${rule.id}`;
      if (await this.redis.get(cacheKey)) continue;

      if (rule.type === 'OVERSPEED' && gpsData.speed > rule.threshold.speed) {
        triggered.push(rule);
        await this.pool.query('INSERT INTO alert_events (rule_id, device_id) VALUES ($1, $2)', [rule.id, deviceId]);
        await this.redis.set(cacheKey, '1', 'EX', rule.cooldown_minutes * 60);
      }
      // Add more rules (geofence, etc.)
    }

    return triggered;
  }

  async getAlerts(deviceId) {
    const result = await this.pool.query('SELECT * FROM alert_events WHERE device_id = $1', [deviceId]);
    return result.rows;
  }
}

module.exports = AlertService;
