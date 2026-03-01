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


-- ================================================
-- GPS LIVE TRACKING DATA
-- ================================================

CREATE TABLE gps_live_data (
    device_id UUID PRIMARY KEY REFERENCES devices(id),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    speed DECIMAL(6,2),
    heading DECIMAL(6,2),
    altitude DECIMAL(8,2),
    accuracy DECIMAL(6,2),
    satellites INTEGER,
    ignition_status BOOLEAN,
    engine_status BOOLEAN,
    battery_voltage DECIMAL(5,2),
    signal_strength INTEGER,
    movement_status VARCHAR(20),
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_gps_live_device ON gps_live_data(device_id);
CREATE INDEX idx_gps_live_update ON gps_live_data(last_update);

-- GPS HISTORY - PARTITIONED BY DATE
CREATE TABLE gps_history (
    id UUID DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES devices(id),
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    speed DECIMAL(6,2),
    heading DECIMAL(6,2),
    altitude DECIMAL(8,2),
    accuracy DECIMAL(6,2),
    satellites INTEGER,
    ignition_status BOOLEAN,
    engine_status BOOLEAN,
    battery_voltage DECIMAL(5,2),
    signal_strength INTEGER,
    raw_packet JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) PARTITION BY RANGE (created_at);

CREATE INDEX idx_gps_history_device ON gps_history(device_id);
CREATE INDEX idx_gps_history_time ON gps_history(created_at);
CREATE INDEX idx_gps_history_device_time ON gps_history(device_id, created_at);

-- ================================================
-- TRIPS & ROUTES
-- ================================================

CREATE TABLE trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES devices(id),
    vehicle_id UUID REFERENCES vehicles(id),
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    start_location GEOGRAPHY(POINT, 4326),
    end_location GEOGRAPHY(POINT, 4326),
    total_distance DECIMAL(10,2),
    max_speed DECIMAL(6,2),
    avg_speed DECIMAL(6,2),
    duration_minutes INTEGER,
    idle_time_minutes INTEGER,
    harsh_braking_count INTEGER DEFAULT 0,
    harsh_acceleration_count INTEGER DEFAULT 0,
    trip_status VARCHAR(20) DEFAULT 'ongoing',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_trips_device ON trips(device_id);
CREATE INDEX idx_trips_vehicle ON trips(vehicle_id);
CREATE INDEX idx_trips_time ON trips(start_time);

-- ================================================
-- COMMANDS & DEVICE CONTROL
-- ================================================

CREATE TABLE device_commands (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES devices(id),
    logical_command VARCHAR(50) NOT NULL,
    actual_command TEXT,
    command_status VARCHAR(20) DEFAULT 'pending',
    priority VARCHAR(20) DEFAULT 'normal',
    sent_at TIMESTAMP,
    executed_at TIMESTAMP,
    ack_received BOOLEAN DEFAULT false,
    ack_time TIMESTAMP,
    result TEXT,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    requested_by UUID REFERENCES users(id),
    otp_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_commands_device ON device_commands(device_id);
CREATE INDEX idx_commands_status ON device_commands(command_status);
CREATE INDEX idx_commands_time ON device_commands(created_at);

-- ================================================
-- ALERTS & NOTIFICATIONS
-- ================================================

CREATE TABLE alert_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES clients(id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    rule_type VARCHAR(50) NOT NULL,
    condition JSONB NOT NULL,
    severity VARCHAR(20) DEFAULT 'warning',
    cooldown_minutes INTEGER DEFAULT 5,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES devices(id),
    alert_rule_id UUID REFERENCES alert_rules(id),
    severity VARCHAR(20),
    message TEXT NOT NULL,
    triggered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acknowledged_at TIMESTAMP,
    acknowledged_by UUID REFERENCES users(id),
    resolved_at TIMESTAMP,
    is_resolved BOOLEAN DEFAULT false
);

CREATE INDEX idx_alerts_device ON alerts(device_id);
CREATE INDEX idx_alerts_status ON alerts(is_resolved);
CREATE INDEX idx_alerts_time ON alerts(triggered_at);

-- ================================================
-- BILLING & SUBSCRIPTIONS
-- ================================================

CREATE TABLE subscription_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    billing_period VARCHAR(20) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    device_limit INTEGER,
    features JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES clients(id),
    plan_id UUID REFERENCES subscription_plans(id),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    auto_renew BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================
-- AUDIT LOGS
-- ================================================

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    action VARCHAR(255) NOT NULL,
    entity_type VARCHAR(100),
    entity_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_time ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);

-- ================================================
-- FUEL DATA
-- ================================================

CREATE TABLE fuel_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES devices(id),
    fuel_level DECIMAL(8,2),
    fuel_consumed DECIMAL(8,2),
    fuel_theft_detected BOOLEAN DEFAULT false,
    anomaly_type VARCHAR(50),
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_fuel_device ON fuel_data(device_id);
CREATE INDEX idx_fuel_time ON fuel_data(recorded_at);

-- ================================================
-- CAN BUS DATA
-- ================================================

CREATE TABLE canbus_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES devices(id),
    rpm INTEGER,
    engine_load DECIMAL(6,2),
    coolant_temp DECIMAL(6,2),
    intake_temp DECIMAL(6,2),
    dtc_code VARCHAR(50),
    dtc_description TEXT,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_canbus_device ON canbus_data(device_id);
CREATE INDEX idx_canbus_time ON canbus_data(recorded_at);

-- ================================================
-- GEOFENCES
-- ================================================

CREATE TABLE geofences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES clients(id),
    name VARCHAR(255) NOT NULL,
    location GEOGRAPHY(POLYGON, 4326) NOT NULL,
    radius_meters INTEGER,
    geofence_type VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_geofence_location ON geofences USING GIST(location);

CREATE TABLE geofence_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES devices(id),
    geofence_id UUID REFERENCES geofences(id),
    event_type VARCHAR(20),
    event_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_geofence_events_device ON geofence_events(device_id);
CREATE INDEX idx_geofence_events_time ON geofence_events(event_time);
