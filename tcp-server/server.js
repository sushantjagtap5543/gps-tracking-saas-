require('dotenv').config();
const net = require('net');
const { Pool } = require('pg');
const Redis = require('redis').createClient();
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'logs/server.log' }),
    new winston.transports.Console()
  ]
});

const pool = new Pool({
  host: process.env.DB_HOST || 'postgres',
  database: process.env.DB_NAME || 'gpstracking',
  user: process.env.DB_USER || 'gpsuser',
  password: process.env.DB_PASSWORD || 'securepass123',
  max: 20
});

const sessions = new Map(); // deviceId -> socket

const server = net.createServer(async (socket) => {
  const clientAddr = `${socket.remoteAddress}:${socket.remotePort}`;
  logger.info(`Device connected: ${clientAddr}`);

  socket.on('data', async (buffer) => {
    try {
      const packet = parseGT06(buffer);
      
      if (packet.type === 'LOGIN') {
        await handleLogin(socket, packet);
      } else if (packet.type === 'GPS') {
        await handleGPS(socket, packet);
      }
      
      socket.write(createAck(packet.protocol, 0x01));
    } catch (error) {
      logger.error(`Packet error: ${error.message}`);
    }
  });

  socket.on('end', async () => {
    logger.info(`Device disconnected: ${clientAddr}`);
    for (let [deviceId, sock] of sessions) {
      if (sock === socket) {
        await markOffline(deviceId);
        sessions.delete(deviceId);
        break;
      }
    }
  });
});

async function handleLogin(socket, packet) {
  const { rows } = await pool.query(
    'SELECT id, is_active FROM devices WHERE imei = $1',
    [packet.imei]
  );
  
  if (rows[0]) {
    const device = rows[0];
    sessions.set(device.id, socket);
    await pool.query(
      'UPDATE devices SET status = $1, last_seen = NOW() WHERE id = $2',
      ['online', device.id]
    );
    logger.info(`Device ${packet.imei} logged in`);
  } else {
    socket.write(createAck(0x01, 0x02)); // Invalid IMEI
    socket.end();
  }
}

async function handleGPS(socket, packet) {
  const deviceId = Array.from(sessions.entries()).find(([_, sock]) => sock === socket)?.[0];
  if (!deviceId) return;

  // Update live data
  await pool.query(`
    INSERT INTO gpslivedata (device_id, latitude, longitude, speed, heading, ignition, raw_data, updated_at)
    VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
    ON CONFLICT (device_id) DO UPDATE SET
      latitude = EXCLUDED.latitude,
      longitude = EXCLUDED.longitude,
      speed = EXCLUDED.speed,
      heading = EXCLUDED.heading,
      ignition = EXCLUDED.ignition,
      updated_at = NOW()
  `, [
    deviceId, packet.latitude, packet.longitude, packet.speed,
    packet.heading, packet.ignition, JSON.stringify(packet)
  ]);

  // Update devices table
  await pool.query(`
    UPDATE devices SET 
      latitude = $2, longitude = $3, speed = $4, 
      heading = $5, ignition = $6, last_seen = NOW(), status = 'online'
    WHERE id = $1
  `, [deviceId, packet.latitude, packet.longitude, packet.speed, packet.heading, packet.ignition]);

  // History
  await pool.query(`
    INSERT INTO gpshistory (device_id, latitude, longitude, speed, heading, ignition, raw_data, gps_time)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
  `, [deviceId, packet.latitude, packet.longitude, packet.speed, packet.heading, packet.ignition, JSON.stringify(packet), packet.timestamp]);

  // Alerts
  if (packet.speed > 120) {
    await pool.query(`
      INSERT INTO alertevents (device_id, type, severity, message)
      VALUES ($1, 'overspeed', 'high', $2)
    `, [deviceId, `Speed: ${packet.speed} km/h`]);
  }
}

// GT06 Protocol Parser (simplified MVP)
function parseGT06(buffer) {
  if (buffer[0] !== 0x78) throw new Error('Invalid GT06');
  
  const protocol = buffer[2];
  if (protocol === 0x01) { // Login
    const imei = buffer.slice(4, 12).toString('hex').match(/.{2}/g).map(bcdToDec).join('');
    return { type: 'LOGIN', imei, protocol };
  }
  
  if (protocol === 0x12 || protocol === 0x13) { // GPS
    const lat = parseLatitude(buffer.slice(12, 16));
    const lng = parseLatitude(buffer.slice(16, 20));
    return {
      type: 'GPS',
      latitude: lat,
      longitude: lng,
      speed: buffer.readUInt8(20),
      heading: buffer.readUInt16BE(21),
      ignition: !!(buffer[23] & 0x01),
      protocol,
      timestamp: new Date()
    };
  }
  
  throw new Error('Unknown protocol');
}

function createAck(protocol, result) {
  const buf = Buffer.alloc(12);
  buf[0] = 0x78; buf[1] = 0x78; buf[2] = protocol;
  buf[3] = 0x04; buf[4] = 0x01; buf[5] = 0x00; buf[6] = result;
  buf[7] = calculateCRC(buf.slice(0, 7));
  buf[8] = 0x0D; buf[9] = 0x0A;
  return buf;
}

server.listen(5001, '0.0.0.0', () => {
  logger.info('TCP Server listening on port 5001');
});
