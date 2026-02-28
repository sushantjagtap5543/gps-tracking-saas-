const uuid = require('uuid');

class CommandService {
  constructor(pool, redis) {
    this.pool = pool;
    this.redis = redis;
  }

  async sendCommand(deviceId, logicalCommand, parameters = {}) {
    const device = await this.pool.query('SELECT * FROM gps_live_data WHERE device_id = $1', [deviceId]);
    if (!device.rows[0]) throw new Error('Device not found');
    if (device.rows[0].speed > 5 && logicalCommand === 'IGNITION_OFF') throw new Error('Cannot off while moving');

    const map = await this.pool.query(`
      SELECT dcm.actual_command, lc.requires_otp
      FROM device_command_map dcm
      JOIN logical_commands lc ON dcm.logical_command_id = lc.id
      JOIN devices d ON dcm.device_model_id = d.model_id
      WHERE d.id = $1 AND lc.name = $2
    `, [deviceId, logicalCommand]);

    if (map.rows.length === 0) throw new Error('No mapping');
    const actualCommand = map.rows[0].actual_command;

    if (map.rows[0].requires_otp) {
      if (!parameters.otp) throw new Error('OTP required');
      const storedOtp = await this.redis.get(`otp:${deviceId}`);
      if (storedOtp !== parameters.otp) throw new Error('Invalid OTP');
    }

    const logId = uuid.v4();
    await this.pool.query(`
      INSERT INTO command_logs (id, device_id, logical_command, actual_command, status)
      VALUES ($1, $2, $3, $4, 'PENDING')
    `, [logId, deviceId, logicalCommand, actualCommand]);

    await this.redis.lpush('command_queue', JSON.stringify({ logId, deviceId, actualCommand }));

    return { status: 'QUEUED', logId };
  }

  async handleAck(logId, success) {
    const status = success ? 'SUCCESS' : 'FAILED';
    await this.pool.query('UPDATE command_logs SET status = $1 WHERE id = $2', [status, logId]);
  }
}

module.exports = CommandService;
