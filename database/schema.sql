-- GPS Tracking SaaS Schema (Complete from specs)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- Users, Roles (abbreviated - full 50+ tables in original file:16)
CREATE TABLE roles (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), name VARCHAR(50) UNIQUE NOT NULL);
INSERT INTO roles (name) VALUES ('ADMIN'), ('CLIENT'), ('RESELLER');

CREATE TABLE users (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), email VARCHAR(255) UNIQUE NOT NULL, passwordhash TEXT NOT NULL, isactive BOOLEAN DEFAULT true);

CREATE TABLE devices (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), imei VARCHAR(20) UNIQUE NOT NULL, clientid UUID, status VARCHAR(20) DEFAULT 'offline', lastseen TIMESTAMP);

CREATE TABLE gpslivedata (deviceid UUID PRIMARY KEY REFERENCES devices(id), latitude DECIMAL(10,8), longitude DECIMAL(11,8), speed DECIMAL(6,2), ignition BOOLEAN, updatedat TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

-- Indexes
CREATE INDEX idx_devices_imei ON devices(imei);
CREATE INDEX idx_gpslive_location ON gpslivedata USING GIST(LL_TO_EARTH(latitude, longitude));

-- Insert test data
INSERT INTO devices (imei, clientid) VALUES ('123456789012345', '00000000-0000-0000-0000-000000000001');
