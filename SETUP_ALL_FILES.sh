#!/bin/bash

############################################################
# GPS TRACKING SAAS - COMPLETE AUTOMATED SETUP SCRIPT
# This script creates ALL missing files for production deployment
# Run: chmod +x SETUP_ALL_FILES.sh && ./SETUP_ALL_FILES.sh
############################################################

set -e  # Exit on error

echo "🚀 Starting GPS Tracking SaaS Complete Setup..."
echo "This will create all missing files with production-ready code"

# Create directory structure
echo "📁 Creating directory structure..."

mkdir -p database/{migrations,seeds}
mkdir -p backend/src/{controllers,services,models,middleware,utils,config,routes}
mkdir -p tcp-server/{protocols,sessions,queue}
mkdir -p web-frontend/{pages,components,services,styles,public}
mkdir -p android-app/app/src/main/{java/com/gps,res}
mkdir -p infra/{docker,nginx,scripts,monitoring}
mkdir -p docs
mkdir -p tests/{unit,integration}
mkdir -p logs

echo "✅ Directory structure created"

############################################################
# 1. DATABASE SCHEMA - COMPLETE PRODUCTION SCHEMA
############################################################

echo "📝 Creating database schema..."

cat > database/schema.sql << 'EOF'
-- GPS TRACKING SAAS - COMPLETE PRODUCTION DATABASE SCHEMA
-- PostgreSQL 14+

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";  -- For geospatial data
CREATE EXTENSION IF NOT EXISTS "btree_gin"; -- For advanced indexing

-- ==================================================
-- 1. CORE AUTH & PERMISSIONS
-- ==================================================

CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    permissions JSONB DEFAULT '[]'::jsonb,
    is_system_role BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(255),
    phone VARCHAR(20),
    avatar_url TEXT,
    
    -- 2FA
    two_factor_enabled BOOLEAN DEFAULT false,
    two_factor_secret TEXT,
    otp_required BOOLEAN DEFAULT false,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_locked BOOLEAN DEFAULT false,
    login_attempts INTEGER DEFAULT 0,
    last_login_at TIMESTAMP,
    last_login_ip INET,
    
    -- Metadata
    timezone VARCHAR(50) DEFAULT 'UTC',
    language VARCHAR(10) DEFAULT 'en',
    notification_preferences JSONB DEFAULT '{"push":true,"email":true,"sms":false}'::jsonb,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id),
    
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$')
);

CREATE TABLE user_roles (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES roles(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES users(id),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    PRIMARY KEY (user_id, role_id)
);

-- ==================================================
-- 2. RESELLER & WHITE-LABEL
-- ==================================================

CREATE TABLE resellers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name VARCHAR(255) NOT NULL,
    contact_name VARCHAR(255),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    
    -- White-label settings
    subdomain VARCHAR(100) UNIQUE,
    custom_domain VARCHAR(255),
    logo_url TEXT,
    favicon_url TEXT,
    primary_color VARCHAR(7) DEFAULT '#2563eb',
    secondary_color VARCHAR(7) DEFAULT '#1e40af',
    
    -- Business
    commission_percent DECIMAL(5,2) DEFAULT 0,
    monthly_fee DECIMAL(10,2) DEFAULT 0,
    min_device_commitment INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    subscription_tier VARCHAR(50) DEFAULT 'basic',
    
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
    
    -- Preferences
    alert_webhook_url TEXT,
    report_frequency VARCHAR(20) DEFAULT 'daily',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

-- ==================================================
-- 3. DEVICE MANAGEMENT
-- ==================================================

CREATE TABLE device_models (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    manufacturer VARCHAR(100) NOT NULL,
    model_name VARCHAR(100) NOT NULL,
    protocol VARCHAR(50) NOT NULL,  -- GT06, Teltonika, etc.
    
    -- Technical specs
    tcp_port INTEGER DEFAULT 5001,
    supports_commands BOOLEAN DEFAULT true,
    supports_fuel BOOLEAN DEFAULT false,
    supports_canbus BOOLEAN DEFAULT false,
    
    -- Documentation
    datasheet_url TEXT,
    manual_url TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(manufacturer, model_name)
);

CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    imei VARCHAR(20) UNIQUE NOT NULL,
    sim_number VARCHAR(20),
    device_model_id UUID REFERENCES device_models(id),
    client_id UUID REFERENCES clients(id),
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_online BOOLEAN DEFAULT false,
    last_seen_at TIMESTAMP,
    last_location GEOGRAPHY(POINT, 4326),
    
    -- Connection info
    server_ip INET,
    connection_time TIMESTAMP,
    
    -- Metadata
    device_name VARCHAR(100),
    installed_at TIMESTAMP,
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT imei_format CHECK (imei ~ '^[0-9]{15}$')
);

CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES clients(id),
    device_id UUID UNIQUE REFERENCES devices(id),
    
    -- Vehicle info
    registration_number VARCHAR(50) NOT NULL,
    make VARCHAR(100),
    model VARCHAR(100),
    year INTEGER,
    color VARCHAR(50),
    fuel_type VARCHAR(20),
    
    -- Identification
    vin VARCHAR(17),
    chassis_number VARCHAR(50),
    engine_number VARCHAR(50),
    
    -- Ownership
    owner_name VARCHAR(255),
    owner_phone VARCHAR(20),
    
    -- Documentation
    insurance_expiry DATE,
    registration_expiry DATE,
    pollution_expiry DATE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================================================
