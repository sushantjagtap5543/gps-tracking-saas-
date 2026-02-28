class LiveMapService {
  constructor(pool, redis) {
    this.pool = pool;
    this.redis = redis;
  }

  async getLiveLocation(deviceId) {
    const result = await this.pool.query('SELECT * FROM gps_live_data WHERE device_id = $1', [deviceId]);
    if (result.rows.length === 0) return null;
    const data = result.rows[0];
    return {
      lat: data.latitude,
      lng: data.longitude,
      speed: data.speed,
      heading: data.heading
    };
  }

  async updateLocation(deviceId, gpsData) {
    await this.pool.query('UPDATE gps_live_data SET latitude = $1, longitude = $2, speed = $3, heading = $4, last_seen = NOW(), status = $5 WHERE device_id = $6', [gpsData.lat, gpsData.lng, gpsData.speed, gpsData.heading, gpsData.status, deviceId]);
    await this.pool.query('INSERT INTO gps_history (device_id, latitude, longitude, speed, heading, timestamp) VALUES ($1, $2, $3, $4, $5, NOW())', [deviceId, gpsData.lat, gpsData.lng, gpsData.speed, gpsData.heading]);
  }
}

module.exports = LiveMapService;
