-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Roles
CREATE TABLE roles (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), name VARCHAR(50) UNIQUE NOT NULL, description TEXT, permissions JSONB DEFAULT '[]', created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

-- Users
CREATE TABLE users (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), email VARCHAR(255) UNIQUE NOT NULL, password_hash TEXT NOT NULL, full_name VARCHAR(255), phone VARCHAR(20), role_id UUID REFERENCES roles(id), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

-- Device Models
CREATE TABLE device_models (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), name VARCHAR(50) UNIQUE NOT NULL, protocol VARCHAR(50), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

-- Devices
CREATE TABLE devices (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), imei VARCHAR(20) UNIQUE NOT NULL, model_id UUID REFERENCES device_models(id), status VARCHAR(20) DEFAULT 'OFFLINE', last_seen TIMESTAMP, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

-- GPS Live Data
CREATE TABLE gps_live_data (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), device_id UUID REFERENCES devices(id), latitude DOUBLE PRECISION, longitude DOUBLE PRECISION, speed DOUBLE PRECISION, heading DOUBLE PRECISION, ignition BOOLEAN, last_seen TIMESTAMP, status VARCHAR(20) DEFAULT 'OFFLINE');

-- GPS History
CREATE TABLE gps_history (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), device_id UUID REFERENCES devices(id), latitude DOUBLE PRECISION, longitude DOUBLE PRECISION, speed DOUBLE PRECISION, heading DOUBLE PRECISION, timestamp TIMESTAMP NOT NULL) PARTITION BY RANGE (timestamp);

CREATE TABLE gps_history_2026 PARTITION OF gps_history FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

-- Logical Commands
CREATE TABLE logical_commands (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), name VARCHAR(50) UNIQUE NOT NULL, category VARCHAR(50), requires_otp BOOLEAN DEFAULT false);

-- Device Command Map
CREATE TABLE device_command_map (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), device_model_id UUID REFERENCES device_models(id), logical_command_id UUID REFERENCES logical_commands(id), actual_command TEXT NOT NULL);

-- Command Logs
CREATE TABLE command_logs (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), device_id UUID REFERENCES devices(id), logical_command VARCHAR(50), actual_command TEXT, status VARCHAR(20) DEFAULT 'PENDING', attempt_count INTEGER DEFAULT 0, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

-- Alert Rules
CREATE TABLE alert_rules (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), name VARCHAR(50), type VARCHAR(50), threshold JSONB, cooldown_minutes INTEGER DEFAULT 5);

-- Alert Events
CREATE TABLE alert_events (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), rule_id UUID REFERENCES alert_rules(id), device_id UUID REFERENCES devices(id), triggered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

-- Trips
CREATE TABLE trips (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), device_id UUID REFERENCES devices(id), start_time TIMESTAMP, end_time TIMESTAMP, distance DECIMAL(10,2), duration INTEGER, avg_speed DECIMAL(6,2));

-- Daily Summaries
CREATE TABLE daily_summaries (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), device_id UUID REFERENCES devices(id), date DATE NOT NULL, total_distance DECIMAL(10,2) DEFAULT 0, total_duration INTEGER DEFAULT 0);

-- Plans
CREATE TABLE plans (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), name VARCHAR(50), price_monthly DECIMAL(10,2), max_devices INTEGER);

-- Subscriptions
CREATE TABLE subscriptions (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), user_id UUID REFERENCES users(id), plan_id UUID REFERENCES plans(id), start_date DATE, end_date DATE, status VARCHAR(20) DEFAULT 'ACTIVE');

-- Resellers
CREATE TABLE resellers (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), user_id UUID REFERENCES users(id), subdomain VARCHAR(50) UNIQUE, custom_domain VARCHAR(100));

-- Reseller Commissions
CREATE TABLE reseller_commissions (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), reseller_id UUID REFERENCES resellers(id), amount DECIMAL(10,2));

-- Driver Scores
CREATE TABLE driver_scores (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), user_id UUID REFERENCES users(id), score INTEGER, period_start DATE, period_end DATE);

-- Indexes
CREATE INDEX idx_gps_live_data_device ON gps_live_data(device_id);
CREATE INDEX idx_gps_history_device_time ON gps_history(device_id, timestamp DESC);
-- Add more as per documents...

-- Seed
INSERT INTO roles (name) VALUES ('SUPER_ADMIN'), ('ADMIN'), ('RESELLER'), ('CLIENT');
INSERT INTO device_models (name, protocol) VALUES ('GT06', 'GT06');
INSERT INTO logical_commands (name) VALUES ('IGNITION_OFF'), ('IGNITION_ON');
INSERT INTO device_command_map (device_model_id, logical_command_id, actual_command) VALUES
    ((SELECT id FROM device_models WHERE name = 'GT06'), (SELECT id FROM logical_commands WHERE name = 'IGNITION_OFF'), 'RELAY,1#'),
    ((SELECT id FROM device_models WHERE name = 'GT06'), (SELECT id FROM logical_commands WHERE name = 'IGNITION_ON'), 'RELAY,0#');
