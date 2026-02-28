class ReportService {
  constructor(pool) {
    this.pool = pool;
  }

  async getKpis(deviceId, start, end) {
    const result = await this.pool.query('SELECT SUM(distance) as total_distance, SUM(duration) as total_duration FROM trips WHERE device_id = $1 AND start_time BETWEEN $2 AND $3', [deviceId, start, end]);
    return result.rows[0];
  }

  // Export to CSV (use csv-stringify or similar)
}

module.exports = ReportService;
