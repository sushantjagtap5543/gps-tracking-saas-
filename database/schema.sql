sql
-- ============================================
-- GPS TRACKING SAAS - COMPLETE PRODUCTION SCHEMA
-- PostgreSQL 15+ with PostGIS
-- ============================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- ============================================
-- CORE TABLES
-- ============================================

CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    permissions JSONB DEFAULT '[]',
    is_system_role BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID
);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(255),
    phone VARCHAR(20),
    avatar_url TEXT,
    two_factor_enabled BOOLEAN DEFAULT false,
    two_factor_secret TEXT,
    is_active BOOLEAN DEFAULT true,
    is_locked BOOLEAN DEFAULT false,
    login_attempts INTEGER DEFAULT 0,
    last_login_at TIMESTAMP,
    last_login_ip INET,
    timezone VARCHAR(50) DEFAULT 'UTC',
    language VARCHAR(10) DEFAULT 'en',
    notification_preferences JSONB DEFAULT '{"push": true, "email": true, "sms": false}',
    fcm_token TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

CREATE TABLE user_roles (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES roles(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES users(id),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE resellers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name VARCHAR(255) NOT NULL,
    contact_name VARCHAR(255),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    subdomain VARCHAR(100) UNIQUE,
    custom_domain VARCHAR(255),
    logo_url TEXT,
    favicon_url TEXT,
    primary_color VARCHAR(7) DEFAULT '#2563eb',
    secondary_color VARCHAR(7) DEFAULT '#1e40af',
    commission_percent DECIMAL(5,2) DEFAULT 0,
    monthly_fee DECIMAL(10,2) DEFAULT 0,
    min_device_commitment INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

CREATE TABLE clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reseller_id UUID REFERENCES resellers(id),
    user_id UUID UNIQUE REFERENCES users(id),
    company_name VARCHAR(255),
    tax_id VARCHAR(50),
    billing_address TEXT,
    billing_email VARCHAR(255),
    billing_phone VARCHAR(20),
    allow_client_ignition BOOLEAN DEFAULT false,
    alert_webhook_url TEXT,
    report_frequency VARCHAR(20) DEFAULT 'daily',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

-- ============================================
-- DEVICE MANAGEMENT
-- ============================================

CREATE TABLE device_models (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    manufacturer VARCHAR(100),
    protocol VARCHAR(50) NOT NULL,
    protocol_version VARCHAR(20),
    supports_ignition BOOLEAN DEFAULT true,
    supports_fuel BOOLEAN DEFAULT false,
    supports_temperature BOOLEAN DEFAULT false,
    supports_canbus BOOLEAN DEFAULT false,
    command_format JSONB DEFAULT '{
        "ignition_on": null,
        "ignition_off": null,
        "restart": null,
        "reboot": null,
        "get_location": null
    }',
    packet_structure JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sim_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    iccid VARCHAR(30) UNIQUE NOT NULL,
    imsi VARCHAR(20),
    phone_number VARCHAR(20),
    operator VARCHAR(50),
    data_plan VARCHAR(50),
    data_limit_mb INTEGER,
    data_used_mb INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    activation_date DATE,
    expiry_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    imei VARCHAR(20) UNIQUE NOT NULL,
    model_id UUID REFERENCES device_models(id),
    sim_id UUID REFERENCES sim_cards(id),
    serial_number VARCHAR(50),
    mac_address VARCHAR(17),
    firmware_version VARCHAR(50),
    hardware_version VARCHAR(50),
    name VARCHAR(100),
    client_id UUID REFERENCES clients(id),
    current_vehicle_id UUID,
    status VARCHAR(20) DEFAULT 'offline',
    connection_status VARCHAR(20) DEFAULT 'disconnected',
    last_seen TIMESTAMP,
    last_ip INET,
    last_packet_time TIMESTAMP,
    total_uptime_minutes INTEGER DEFAULT 0,
    packet_count BIGINT DEFAULT 0,
    subscription_start DATE,
    subscription_expiry DATE,
    grace_period_end DATE,
    is_subscription_active BOOLEAN DEFAULT true,
    last_latitude DECIMAL(10,8),
    last_longitude DECIMAL(11,8),
    last_speed DECIMAL(6,2),
    last_heading DECIMAL(5,2),
    last_altitude DECIMAL(8,2),
    installation_date DATE,
    installation_notes TEXT,
    qr_code TEXT,
    qr_scanned_at TIMESTAMP,
    is_blacklisted BOOLEAN DEFAULT false,
    blacklist_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id),
    CONSTRAINT valid_imei CHECK (imei ~ '^[0-9]{15,17}$')
);

CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES clients(id) NOT NULL,
    registration_number VARCHAR(50) UNIQUE NOT NULL,
    vin VARCHAR(17),
    chassis_number VARCHAR(50),
    engine_number VARCHAR(50),
    make VARCHAR(50),
    model VARCHAR(50),
    year INTEGER,
    fuel_type VARCHAR(20),
    fuel_capacity_liters DECIMAL(8,2),
    color VARCHAR(30),
    engine_capacity_cc INTEGER,
    gross_weight_kg INTEGER,
    seating_capacity INTEGER,
    current_device_id UUID REFERENCES devices(id),
    current_driver_id UUID,
    odometer_reading INTEGER DEFAULT 0,
    last_maintenance_at TIMESTAMP,
    next_maintenance_due TIMESTAMP,
    insurance_expiry DATE,
    registration_expiry DATE,
    is_active BOOLEAN DEFAULT true,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

CREATE TABLE device_vehicle_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    removed_at TIMESTAMP,
    assigned_by UUID REFERENCES users(id),
    is_current BOOLEAN DEFAULT true,
    vehicle_odometer INTEGER,
    device_packet_count BIGINT
);

-- ============================================
-- GPS TRACKING DATA
-- ============================================

CREATE TABLE gps_live_data (
    device_id UUID PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    altitude DECIMAL(8,2),
    speed DECIMAL(6,2),
    heading DECIMAL(5,2),
    location_point GEOGRAPHY(POINT),
    reverse_geocoded_address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    postal_code VARCHAR(20),
    satellites INTEGER,
    gsm_signal INTEGER,
    ignition BOOLEAN DEFAULT false,
    motion BOOLEAN DEFAULT false,
    charging BOOLEAN DEFAULT false,
    battery_level DECIMAL(5,2),
    external_power BOOLEAN DEFAULT true,
    distance_since_start DECIMAL(10,2),
    trip_id UUID,
    raw_data JSONB,
    protocol_data JSONB,
    device_time TIMESTAMP,
    server_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_gps_live_location ON gps_live_data USING GIST(location_point);

CREATE TABLE gps_history (
    id UUID DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES devices(id),
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    altitude DECIMAL(8,2),
    speed DECIMAL(6,2),
    heading DECIMAL(5,2),
    satellites INTEGER,
    gsm_signal INTEGER,
    ignition BOOLEAN,
    motion BOOLEAN,
    charging BOOLEAN,
    battery_level DECIMAL(5,2),
    external_power BOOLEAN,
    distance_delta DECIMAL(10,2),
    location_point GEOGRAPHY(POINT),
    raw_data JSONB,
    protocol_data JSONB,
    device_time TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    trip_id UUID,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

DO $$
DECLARE
    start_date DATE;
    end_date DATE;
    partition_name TEXT;
BEGIN
    FOR i IN 0..11 LOOP
        start_date := DATE_TRUNC('month', CURRENT_DATE + (i || ' months')::INTERVAL);
        end_date := DATE_TRUNC('month', CURRENT_DATE + ((i+1) || ' months')::INTERVAL);
        partition_name := 'gps_history_' || TO_CHAR(start_date, 'YYYY_MM');
        
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I PARTITION OF gps_history
            FOR VALUES FROM (%L) TO (%L)',
            partition_name, start_date, end_date
        );
    END LOOP;
END $$;

CREATE TABLE gps_history_default PARTITION OF gps_history DEFAULT;

-- ============================================
-- COMMAND SYSTEM
-- ============================================

CREATE TABLE logical_commands (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) UNIQUE NOT NULL,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    parameters_schema JSONB,
    requires_otp BOOLEAN DEFAULT false,
    requires_approval BOOLEAN DEFAULT false,
    safety_check_required BOOLEAN DEFAULT true,
    is_reversible BOOLEAN DEFAULT true,
    timeout_seconds INTEGER DEFAULT 30,
    max_retries INTEGER DEFAULT 3,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO logical_commands (name, category, description, requires_otp, safety_check_required) VALUES
    ('IGNITION_ON', 'ignition', 'Turn ignition ON', true, true),
    ('IGNITION_OFF', 'ignition', 'Turn ignition OFF', true, true),
    ('ENGINE_RESTART', 'ignition', 'Restart engine', true, true),
    ('ARM_IMMOBILIZER', 'immobilizer', 'Arm immobilizer', true, false),
    ('DISARM_IMMOBILIZER', 'immobilizer', 'Disarm immobilizer', true, false),
    ('GET_LOCATION', 'location', 'Request immediate location', false, false),
    ('REBOOT_DEVICE', 'config', 'Reboot GPS device', false, true),
    ('SET_SLEEP_MODE', 'config', 'Put device in sleep mode', false, true),
    ('SET_WAKE_MODE', 'config', 'Wake device from sleep', false, true),
    ('CUSTOM_COMMAND', 'custom', 'Send custom command', false, false);

CREATE TABLE device_command_map (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_model_id UUID REFERENCES device_models(id) ON DELETE CASCADE,
    logical_command_id UUID REFERENCES logical_commands(id) ON DELETE CASCADE,
    actual_command TEXT NOT NULL,
    command_format VARCHAR(50) DEFAULT 'text',
    parameters_mapping JSONB,
    timeout_seconds INTEGER,
    retry_count INTEGER,
    requires_ack BOOLEAN DEFAULT true,
    success_response_pattern TEXT,
    failure_response_pattern TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(device_model_id, logical_command_id)
);

CREATE TABLE command_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES devices(id) NOT NULL,
    command_log_id UUID,
    priority INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'QUEUED',
    execute_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    last_attempt TIMESTAMP,
    attempt_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

CREATE TABLE command_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES devices(id) NOT NULL,
    logical_command_id UUID REFERENCES logical_commands(id),
    command_text TEXT NOT NULL,
    parameters JSONB,
    requested_by UUID REFERENCES users(id),
    requested_from_ip INET,
    requested_from_user_agent TEXT,
    approval_required BOOLEAN DEFAULT false,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP,
    safety_checks_passed BOOLEAN,
    vehicle_speed_at_command DECIMAL,
    vehicle_ignition_state BOOLEAN,
    otp_verified BOOLEAN DEFAULT false,
    otp_code VARCHAR(10),
    status VARCHAR(20) NOT NULL,
    attempt_count INTEGER DEFAULT 0,
    response_data JSONB,
    error_message TEXT,
    execution_time_ms INTEGER,
    ack_received BOOLEAN DEFAULT false,
    ack_data JSONB,
    device_response_time_ms INTEGER,
    queued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    command_date DATE GENERATED ALWAYS AS (DATE(created_at)) STORED
) PARTITION BY RANGE (created_at);

CREATE TABLE command_logs_default PARTITION OF command_logs DEFAULT;

-- ============================================
-- ALERT SYSTEM
-- ============================================

CREATE TABLE alert_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL,
    condition JSONB NOT NULL,
    severity VARCHAR(20) DEFAULT 'WARNING',
    cooldown_minutes INTEGER DEFAULT 0,
    time_window_start TIME,
    time_window_end TIME,
    days_of_week INTEGER[],
    notify_in_app BOOLEAN DEFAULT true,
    notify_push BOOLEAN DEFAULT true,
    notify_email BOOLEAN DEFAULT false,
    notify_sms BOOLEAN DEFAULT false,
    notify_whatsapp BOOLEAN DEFAULT false,
    notify_webhook BOOLEAN DEFAULT false,
    webhook_url TEXT,
    client_id UUID REFERENCES clients(id),
    vehicle_id UUID REFERENCES vehicles(id),
    is_global BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

CREATE TABLE alert_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rule_id UUID REFERENCES alert_rules(id),
    device_id UUID REFERENCES devices(id),
    vehicle_id UUID REFERENCES vehicles(id),
    client_id UUID REFERENCES clients(id),
    severity VARCHAR(20),
    message TEXT,
    details JSONB,
    location GEOGRAPHY(POINT),
    trigger_value TEXT,
    trigger_unit VARCHAR(20),
    status VARCHAR(20) DEFAULT 'ACTIVE',
    acknowledged_by UUID REFERENCES users(id),
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMP,
    triggered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acknowledged_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    alert_event_id UUID REFERENCES alert_events(id),
    channel VARCHAR(20) NOT NULL,
    title TEXT,
    body TEXT,
    data JSONB,
    status VARCHAR(20) DEFAULT 'PENDING',
    provider_response JSONB,
    error_message TEXT,
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TRIPS & PLAYBACK
-- ============================================

CREATE TABLE trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES devices(id) NOT NULL,
    vehicle_id UUID REFERENCES vehicles(id),
    driver_id UUID,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    duration_seconds INTEGER,
    start_latitude DECIMAL(10,8),
    start_longitude DECIMAL(11,8),
    end_latitude DECIMAL(10,8),
    end_longitude DECIMAL(11,8),
    start_address TEXT,
    end_address TEXT,
    distance_meters DECIMAL(10,2),
    max_speed DECIMAL(6,2),
    avg_speed DECIMAL(6,2),
    idle_seconds INTEGER,
    moving_seconds INTEGER,
    fuel_consumed DECIMAL(8,2),
    fuel_avg_kmpl DECIMAL(5,2),
    overspeed_count INTEGER DEFAULT 0,
    harsh_braking_count INTEGER DEFAULT 0,
    harsh_acceleration_count INTEGER DEFAULT 0,
    sharp_turn_count INTEGER DEFAULT 0,
    polyline TEXT,
    route_points JSONB,
    point_count INTEGER,
    is_completed BOOLEAN DEFAULT false,
    is_processed BOOLEAN DEFAULT false,
    driver_score DECIMAL(5,2),
    driver_score_data JSONB,
    scored_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE trip_points (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID REFERENCES trips(id) ON DELETE CASCADE,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    speed DECIMAL(6,2),
    heading DECIMAL(5,2),
    altitude DECIMAL(8,2),
    ignition BOOLEAN,
    distance_from_start DECIMAL(10,2),
    elapsed_seconds INTEGER,
    recorded_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- FUEL & CAN BUS
-- ============================================

CREATE TABLE fuel_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES devices(id),
    vehicle_id UUID REFERENCES vehicles(id),
    level_percent DECIMAL(5,2),
    level_liters DECIMAL(8,2),
    temperature DECIMAL(5,2),
    is_fueling BOOLEAN DEFAULT false,
    is_theft BOOLEAN DEFAULT false,
    fueling_amount DECIMAL(8,2),
    theft_amount DECIMAL(8,2),
    raw_data JSONB,
    sensor_id VARCHAR(50),
    recorded_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE canbus_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES devices(id),
    vehicle_id UUID REFERENCES vehicles(id),
    rpm INTEGER,
    engine_load DECIMAL(5,2),
    coolant_temp DECIMAL(5,2),
    intake_temp DECIMAL(5,2),
    throttle_position DECIMAL(5,2),
    instant_fuel_consumption DECIMAL(8,2),
    avg_fuel_consumption DECIMAL(8,2),
    fuel_pressure DECIMAL(8,2),
    battery_voltage DECIMAL(5,2),
    alternator_voltage DECIMAL(5,2),
    dtc_codes TEXT[],
    check_engine BOOLEAN DEFAULT false,
    obd_standards VARCHAR(20),
    recorded_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- DRIVER SCORING
-- ============================================

CREATE TABLE driver_scores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID,
    vehicle_id UUID REFERENCES vehicles(id),
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    overall_score DECIMAL(5,2),
    speed_score DECIMAL(5,2),
    braking_score DECIMAL(5,2),
    acceleration_score DECIMAL(5,2),
    cornering_score DECIMAL(5,2),
    idle_score DECIMAL(5,2),
    night_driving_score DECIMAL(5,2),
    total_distance DECIMAL(10,2),
    total_driving_hours DECIMAL(8,2),
    trip_count INTEGER,
    overspeed_count INTEGER,
    harsh_braking_count INTEGER,
    harsh_acceleration_count INTEGER,
    sharp_turn_count INTEGER,
    idle_percent DECIMAL(5,2),
    night_driving_percent DECIMAL(5,2),
    risk_level VARCHAR(20),
    trends JSONB,
    tips JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- BILLING & SUBSCRIPTIONS
-- ============================================

CREATE TABLE plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price_monthly DECIMAL(10,2) NOT NULL,
    price_yearly DECIMAL(10,2),
    setup_fee DECIMAL(10,2) DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    max_vehicles INTEGER,
    max_drivers INTEGER,
    features JSONB,
    data_retention_days INTEGER DEFAULT 365,
    support_level VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    is_public BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES clients(id),
    reseller_id UUID REFERENCES resellers(id),
    plan_id UUID REFERENCES plans(id),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    grace_period_end DATE,
    auto_renew BOOLEAN DEFAULT true,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    price_monthly DECIMAL(10,2),
    price_yearly DECIMAL(10,2),
    setup_fee DECIMAL(10,2),
    billing_cycle VARCHAR(20) DEFAULT 'MONTHLY',
    next_billing_date DATE,
    last_invoice_id UUID,
    device_limit INTEGER,
    devices_used INTEGER DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subscription_id UUID REFERENCES subscriptions(id),
    client_id UUID REFERENCES clients(id),
    invoice_number VARCHAR(50) UNIQUE,
    amount DECIMAL(10,2) NOT NULL,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    period_start DATE,
    period_end DATE,
    due_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    paid_at TIMESTAMP,
    payment_method VARCHAR(50),
    transaction_id VARCHAR(255),
    items JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID REFERENCES invoices(id),
    client_id UUID REFERENCES clients(id),
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    payment_provider VARCHAR(50),
    transaction_id VARCHAR(255),
    status VARCHAR(20) DEFAULT 'PENDING',
    provider_response JSONB,
    error_message TEXT,
    paid_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- GEOFENCES
-- ============================================

CREATE TABLE geofences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES clients(id),
    name VARCHAR(255) NOT NULL,
    type VARCHAR(20) NOT NULL,
    center_latitude DECIMAL(10,8),
    center_longitude DECIMAL(11,8),
    radius_meters DECIMAL(10,2),
    polygon_coordinates JSONB,
    route_coordinates JSONB,
    geometry GEOGRAPHY,
    speed_limit DECIMAL(6,2),
    alert_on_enter BOOLEAN DEFAULT true,
    alert_on_exit BOOLEAN DEFAULT true,
    alert_on_speed BOOLEAN DEFAULT false,
    active_24_7 BOOLEAN DEFAULT true,
    time_window_start TIME,
    time_window_end TIME,
    days_of_week INTEGER[],
    color VARCHAR(7) DEFAULT '#2563eb',
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

-- ============================================
-- WHITE LABEL SETTINGS
-- ============================================

CREATE TABLE white_label_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reseller_id UUID REFERENCES resellers(id) ON DELETE CASCADE,
    primary_color VARCHAR(7) DEFAULT '#2563eb',
    secondary_color VARCHAR(7) DEFAULT '#1e40af',
    logo_url TEXT,
    favicon_url TEXT,
    custom_css TEXT,
    custom_domain VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(reseller_id)
);

-- ============================================
-- AUDIT & SECURITY
-- ============================================

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    user_email VARCHAR(255),
    user_role VARCHAR(50),
    action VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50),
    entity_id UUID,
    entity_name VARCHAR(255),
    old_values JSONB,
    new_values JSONB,
    diff JSONB,
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(255),
    request_id VARCHAR(255),
    request_path TEXT,
    request_method VARCHAR(10),
    status VARCHAR(20) DEFAULT 'SUCCESS',
    error_message TEXT,
    response_time_ms INTEGER,
    location GEOGRAPHY(POINT),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) PARTITION BY RANGE (created_at);

CREATE TABLE audit_logs_default PARTITION OF audit_logs DEFAULT;

CREATE TABLE login_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    email VARCHAR(255),
    success BOOLEAN DEFAULT true,
    ip_address INET,
    user_agent TEXT,
    two_factor_used BOOLEAN DEFAULT false,
    two_factor_success BOOLEAN,
    failure_reason VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- SYSTEM CONTROLS
-- ============================================

CREATE TABLE system_controls (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    is_encrypted BOOLEAN DEFAULT false,
    updated_by UUID REFERENCES users(id),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO system_controls (key, value, description) VALUES
    ('global.ignition_disabled', 'false', 'Emergency kill-switch for all ignition commands'),
    ('global.maintenance_mode', 'false', 'Put entire system in read-only mode'),
    ('global.emergency_shutdown', 'false', 'Emergency system shutdown'),
    ('alert.global_cooldown', '5', 'Default cooldown minutes for alerts'),
    ('command.max_retries', '3', 'Global max retry count for commands'),
    ('command.default_timeout', '30', 'Default command timeout in seconds'),
    ('auth.max_login_attempts', '5', 'Max failed login attempts before lock'),
    ('auth.session_timeout', '3600', 'Session timeout in seconds'),
    ('backup.enabled', 'true', 'Enable automatic backups'),
    ('backup.hour', '2', 'Hour of day for backup (UTC)'),
    ('data_retention.days', '730', 'Days to keep detailed history');

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_fcm_token ON users(fcm_token) WHERE fcm_token IS NOT NULL;

CREATE INDEX idx_devices_imei ON devices(imei);
CREATE INDEX idx_devices_client_id ON devices(client_id);
CREATE INDEX idx_devices_model_id ON devices(model_id);
CREATE INDEX idx_devices_status ON devices(status);
CREATE INDEX idx_devices_last_seen ON devices(last_seen DESC);
CREATE INDEX idx_devices_subscription_expiry ON devices(subscription_expiry) WHERE is_subscription_active = true;

CREATE INDEX idx_gps_history_device_time ON gps_history(device_id, device_time DESC);
CREATE INDEX idx_gps_history_created_at ON gps_history(created_at DESC);
CREATE INDEX idx_gps_history_trip_id ON gps_history(trip_id) WHERE trip_id IS NOT NULL;

CREATE INDEX idx_command_logs_device_status ON command_logs(device_id, status, created_at DESC);
CREATE INDEX idx_command_logs_requested_by ON command_logs(requested_by, created_at DESC);
CREATE INDEX idx_command_logs_created_at ON command_logs(created_at DESC);

CREATE INDEX idx_alert_events_device_triggered ON alert_events(device_id, triggered_at DESC);
CREATE INDEX idx_alert_events_status ON alert_events(status, triggered_at DESC);
CREATE INDEX idx_alert_events_rule_id ON alert_events(rule_id, triggered_at DESC);

CREATE INDEX idx_trips_device_start ON trips(device_id, start_time DESC);
CREATE INDEX idx_trips_vehicle_start ON trips(vehicle_id, start_time DESC);
CREATE INDEX idx_trips_is_completed ON trips(is_completed, start_time DESC);

CREATE INDEX idx_subscriptions_client_status ON subscriptions(client_id, status);
CREATE INDEX idx_subscriptions_expiry ON subscriptions(end_date) WHERE status = 'ACTIVE';
CREATE INDEX idx_invoices_client_status ON invoices(client_id, status, due_date);

CREATE INDEX idx_audit_logs_user_created ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_logs_category ON audit_logs(category, created_at DESC);
