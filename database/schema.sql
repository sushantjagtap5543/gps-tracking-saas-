-- ENTERPRISE GPS TRACKING PLATFORM
-- Complete PostgreSQL Schema
-- Version 1.0

-- ==========================================
-- USERS TABLE (Admin & Client roles only)
-- ==========================================

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  company_name VARCHAR(255),
  phone VARCHAR(20),
  role VARCHAR(20) CHECK (role IN ('admin', 'client')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- DEVICES TABLE (IMEI locked when LIVE)
-- ==========================================

CREATE TABLE devices (
  id SERIAL PRIMARY KEY,
  imei VARCHAR(15) UNIQUE NOT NULL,
  phone_number VARCHAR(20),
  device_type VARCHAR(50), -- car, truck, motorcycle, etc.
  client_id INT NOT NULL REFERENCES users(id),
  status VARCHAR(20) CHECK (status IN ('PENDING', 'LIVE', 'OFFLINE', 'INACTIVE')),
  is_active BOOLEAN DEFAULT true,
  
  -- Fields locked when status = 'LIVE'
  imei_locked BOOLEAN DEFAULT false,
  phone_number_locked BOOLEAN DEFAULT false,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Constraint: Once device is LIVE, IMEI and phone number become immutable
CREATE TRIGGER lock_device_fields
BEFORE UPDATE ON devices
FOR EACH ROW
BEGIN
  IF OLD.status = 'LIVE' THEN
    IF NEW.imei <> OLD.imei OR NEW.phone_number <> OLD.phone_number THEN
      RAISE EXCEPTION 'Cannot modify IMEI or phone number for LIVE devices';
    END IF;
  END IF;
END;

-- ==========================================
-- GPS LOCATIONS TABLE (Raw, cleaned GPS data)
-- ==========================================

CREATE TABLE gps_locations (
  id BIGSERIAL PRIMARY KEY,
  imei VARCHAR(15) NOT NULL REFERENCES devices(imei),
  latitude DECIMAL(10, 8) NOT NULL,
  longitude DECIMAL(11, 8) NOT NULL,
  speed DECIMAL(7, 2), -- km/h
  heading DECIMAL(5, 2), -- 0-360 degrees
  accuracy DECIMAL(5, 2), -- GPS accuracy in meters
  timestamp TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for real-time queries
CREATE INDEX idx_gps_imei_timestamp ON gps_locations(imei, created_at DESC);
CREATE INDEX idx_gps_coordinates ON gps_locations(latitude, longitude);

-- ==========================================
-- GEOFENCES TABLE (Polygons & circles)
-- ==========================================

CREATE TABLE geofences (
  id SERIAL PRIMARY KEY,
  client_id INT NOT NULL REFERENCES users(id),
  device_id INT NOT NULL REFERENCES devices(id),
  name VARCHAR(255) NOT NULL,
  type VARCHAR(20) CHECK (type IN ('POLYGON', 'CIRCLE')),
  coordinates JSONB NOT NULL, -- {"polygon": [[lat,lng],...]} or {"circle": {"center": {lat,lng}, "radius": meters}}
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- ROUTE GEOFENCE TABLE
-- ==========================================

CREATE TABLE route_geofences (
  id SERIAL PRIMARY KEY,
  client_id INT NOT NULL REFERENCES users(id),
  device_id INT NOT NULL REFERENCES devices(id),
  name VARCHAR(255) NOT NULL,
  route_polyline TEXT NOT NULL, -- Encoded polyline format
  deviation_tolerance INT DEFAULT 50, -- meters (50m default)
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- ALERTS TABLE
-- ==========================================

CREATE TABLE alerts (
  id BIGSERIAL PRIMARY KEY,
  imei VARCHAR(15) NOT NULL,
  client_id INT NOT NULL REFERENCES users(id),
  type VARCHAR(100) NOT NULL, -- SPEED_ALERT, GEOFENCE_VIOLATION, IGNITION_ON, TOWING, TAMPERING, POWER_CUT, ROUTE_DEVIATION
  message TEXT,
  severity VARCHAR(20) CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Alert rule definitions
CREATE TABLE alert_rules (
  id SERIAL PRIMARY KEY,
  client_id INT NOT NULL REFERENCES users(id),
  type VARCHAR(100) NOT NULL,
  enabled BOOLEAN DEFAULT true,
  threshold_value INT, -- e.g., speed limit
  notification_method VARCHAR(50) CHECK (notification_method IN ('EMAIL', 'SMS', 'PUSH', 'ALL')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- SUBSCRIPTIONS TABLE
-- ==========================================

CREATE TABLE subscriptions (
  id SERIAL PRIMARY KEY,
  client_id INT NOT NULL REFERENCES users(id),
  device_id INT NOT NULL REFERENCES devices(id),
  plan_type VARCHAR(50) CHECK (plan_type IN ('MONTHLY', 'QUARTERLY', 'YEARLY')),
  amount DECIMAL(10, 2) NOT NULL,
  start_date TIMESTAMP NOT NULL,
  renewal_date TIMESTAMP NOT NULL,
  status VARCHAR(20) CHECK (status IN ('ACTIVE', 'EXPIRED', 'PAYMENT_DUE', 'CANCELLED')),
  last_payment_date TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- PAYMENTS TABLE
-- ==========================================

CREATE TABLE payments (
  id SERIAL PRIMARY KEY,
  subscription_id INT NOT NULL REFERENCES subscriptions(id),
  client_id INT NOT NULL REFERENCES users(id),
  amount DECIMAL(10, 2) NOT NULL,
  status VARCHAR(20) CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED')),
  stripe_payment_id VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- INFRASTRUCTURE PORTS TABLE
-- ==========================================

CREATE TABLE infrastructure_ports (
  id SERIAL PRIMARY KEY,
  port INT UNIQUE NOT NULL,
  protocol VARCHAR(10) CHECK (protocol IN ('TCP', 'UDP', 'BOTH')),
  device_type VARCHAR(100), -- Device protocol type
  status VARCHAR(20) CHECK (status IN ('AVAILABLE', 'ALLOCATED', 'INACTIVE')),
  assigned_to VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- DEVICE PROTOCOLS TABLE
-- ==========================================

CREATE TABLE device_protocols (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL,
  description TEXT,
  port INT REFERENCES infrastructure_ports(port),
  protocol VARCHAR(10),
  parser_config JSONB,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- AUDIT LOG TABLE
-- ==========================================

CREATE TABLE audit_logs (
  id BIGSERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id),
  action VARCHAR(255),
  resource_type VARCHAR(50),
  resource_id INT,
  old_value JSONB,
  new_value JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- NOTIFICATIONS TABLE
-- ==========================================

CREATE TABLE notifications (
  id BIGSERIAL PRIMARY KEY,
  client_id INT NOT NULL REFERENCES users(id),
  alert_id BIGINT REFERENCES alerts(id),
  type VARCHAR(20) CHECK (type IN ('EMAIL', 'SMS', 'PUSH')),
  recipient VARCHAR(255), -- email, phone, or device token
  message TEXT,
  status VARCHAR(20) CHECK (status IN ('SENT', 'FAILED', 'PENDING')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- DEMO DATA (Optional)
-- ==========================================

-- Create default device protocols
INSERT INTO device_protocols (name, description, protocol) VALUES
  ('GPS-Tracker-Pro', 'Standard GPS tracking device', 'TCP'),
  ('Fleet-Manager-5000', 'Advanced fleet management device', 'TCP'),
  ('TelemetryBox-X', 'IoT telemetry device', 'UDP');

-- Create infrastructure ports (TCP/UDP allocation)
INSERT INTO infrastructure_ports (port, protocol, status) VALUES
  (5001, 'TCP', 'AVAILABLE'),
  (5002, 'TCP', 'AVAILABLE'),
  (5003, 'TCP', 'AVAILABLE'),
  (5004, 'UDP', 'AVAILABLE'),
  (5005, 'UDP', 'AVAILABLE');

-- ==========================================
-- VIEWS FOR REAL-TIME DASHBOARD
-- ==========================================

CREATE VIEW active_devices_view AS
SELECT 
  d.id,
  d.imei,
  d.device_type,
  d.status,
  u.company_name,
  g.latitude,
  g.longitude,
  g.speed,
  g.heading,
  g.created_at as last_update
FROM devices d
JOIN users u ON d.client_id = u.id
LEFT JOIN gps_locations g ON d.imei = g.imei 
WHERE d.is_active = true AND d.status = 'LIVE';

CREATE VIEW subscription_status_view AS
SELECT 
  s.id,
  s.client_id,
  u.company_name,
  d.imei,
  s.status,
  s.renewal_date,
  CASE 
    WHEN s.renewal_date <= NOW() THEN 'DUE'
    WHEN s.renewal_date <= NOW() + INTERVAL '7 days' THEN 'UPCOMING'
    ELSE 'ACTIVE'
  END as payment_status
FROM subscriptions s
JOIN users u ON s.client_id = u.id
JOIN devices d ON s.device_id = d.id;

-- ==========================================
-- GRANTS & SECURITY
-- ==========================================

-- Create application user with limited permissions
-- (Execute these separately with superuser role)
-- CREATE ROLE gps_app WITH LOGIN PASSWORD 'secure_password';
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO gps_app;
