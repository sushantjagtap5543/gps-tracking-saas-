class AIScoringService {
  constructor(pool) {
    this.pool = pool;
  }

  async calculateScore(userId, start, end) {
    const trips = await this.pool.query('SELECT * FROM trips WHERE user_id = $1 AND start_time BETWEEN $2 AND $3', [userId, start, end]);
    let score = 100;
    for (const trip of trips.rows) {
      if (trip.avg_speed > 80) score -= 10;
      // Add braking, acceleration
    }
    await this.pool.query('INSERT INTO driver_scores (user_id, score, period_start, period_end) VALUES ($1, $2, $3, $4)', [userId, score, start, end]);
    return score;
  }
}

module.exports = AIScoringService;
