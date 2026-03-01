-- MVP DATABASE SCHEMA v1.0 - GPS TRACKING SAAS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- ROLES
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(50) UNIQUE NOT NULL,
  permissions JSONB DEFAULT '[]',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- USERS
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(50) DEFAULT 'client',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEVICES (GT06 MVP)
CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  imei VARCHAR(20) UNIQUE NOT NULL,
  name VARCHAR(100),
  client_id UUID REFERENCES users(id),
  status VARCHAR(20) DEFAULT 'offline', -- online,offline
  last_seen TIMESTAMP,
  speed DECIMAL(5,2) DEFAULT 0,
  latitude DECIMAL(10,7),
  longitude DECIMAL(10,7),
  heading DECIMAL(5,2) DEFAULT 0,
  ignition BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- LIVE GPS DATA
CREATE TABLE gpslivedata (
  device_id UUID PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
  latitude DECIMAL(10,7),
  longitude DECIMAL(10,7),
  speed DECIMAL(5,2),
  heading DECIMAL(5,2),
  satellites INTEGER,
  ignition BOOLEAN DEFAULT false,
  raw_data JSONB,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- GPS HISTORY
CREATE TABLE gpshistory (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
  latitude DECIMAL(10,7),
  longitude DECIMAL(10,7),
  speed DECIMAL(5,2),
  heading DECIMAL(5,2),
  ignition BOOLEAN,
  raw_data JSONB,
  gps_time TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- COMMANDS
CREATE TABLE logicalcommands (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(50) UNIQUE NOT NULL, -- IGNITION_OFF
  description TEXT
);

CREATE TABLE commandlogs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id UUID REFERENCES devices(id),
  command VARCHAR(50) NOT NULL,
  status VARCHAR(20) DEFAULT 'pending', -- pending,sent,success,failed
  retries INTEGER DEFAULT 0,
  result TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP
);

-- ALERTS
CREATE TABLE alertevents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id UUID REFERENCES devices(id),
  type VARCHAR(50), -- overspeed,offline,ignition
  severity VARCHAR(20),
  message TEXT,
  resolved BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- SEED DATA
INSERT INTO roles (name, permissions) VALUES 
('admin', '["*"]'),
('client', '["view","command"]');

INSERT INTO users (email, password_hash, role) VALUES 
('admin@demo.com', '$2b$10$demo_hash', 'admin'),
('client@demo.com', '$2b$10$demo_hash', 'client');

INSERT INTO logicalcommands (name, description) VALUES 
('IGNITION_OFF', 'Cut engine relay'),
('IGNITION_ON', 'Enable engine'),
('RESTART', 'Device reboot');

-- INDEXES
CREATE INDEX idx_devices_imei ON devices(imei);
CREATE INDEX idx_devices_status ON devices(status);
CREATE INDEX idx_gpshistory_device_time ON gpshistory(device_id, created_at);
CREATE INDEX idx_commandlogs_status ON commandlogs(status);
