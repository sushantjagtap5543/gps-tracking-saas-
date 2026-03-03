# 🚀 ENTERPRISE GPS TRACKING PLATFORM
## Complete Setup & Deployment Guide

---

## ✅ QUICK START (5 Minutes with Docker)

### Prerequisites
- Docker & Docker Compose installed
- Git
- Node.js 18+ (for local development)

### Step 1: Clone & Configure

```bash
# Extract the project
unzip gps-tracking-enterprise.zip
cd gps-tracking-enterprise

# Copy environment file
cp .env.example .env

# Edit .env with your credentials
nano .env
```

### Step 2: Start Services

```bash
# Build and start all services
docker-compose up -d

# Check if all services are running
docker-compose ps

# View logs
docker-compose logs -f backend
```

### Step 3: Access Applications

- **Client App**: http://localhost:3000
- **Admin Portal**: http://localhost:3001
- **API**: http://localhost:5000
- **Health Check**: http://localhost:5000/health

---

## 📝 DEFAULT CREDENTIALS

### Create Admin User

```bash
# Access PostgreSQL
docker-compose exec postgres psql -U gps_admin -d gps_tracking

# Create admin user (replace password with secure one)
INSERT INTO users (email, password, company_name, phone, role, is_active)
VALUES (
  'admin@gpstracking.com',
  '$2a$10$...',  -- Use bcrypt hash
  'GPS Tracking Admin',
  '+1234567890',
  'admin',
  true
);
```

### Login Credentials
- Email: `admin@gpstracking.com`
- Password: (Set in database)

---

## 🏗️ SYSTEM ARCHITECTURE

### Components

**Backend (Node.js + Express)**
- GPS data processing
- Real-time WebSocket updates
- Device management
- Billing & subscriptions
- Alert engine

**Frontend (React)**
- Landing page with login
- Client dashboard
- Live tracking map
- Geofence builder
- Billing management

**Admin Portal**
- Client management
- Device registry
- Infrastructure control (TCP/UDP ports)
- System health monitoring
- Alert management

**Database (PostgreSQL)**
- Complete GPS data storage
- Subscription management
- Alert rules
- Audit logs

**Cache (Redis)**
- Real-time GPS data
- Session management
- Command queues

---

## 🔐 SECURITY SETUP

### 1. Change Default Passwords

Edit `.env`:
```env
DB_PASSWORD=your_secure_db_password
JWT_SECRET=your_secure_jwt_secret
STRIPE_SECRET_KEY=sk_your_stripe_key
```

### 2. Enable HTTPS

```bash
# Install Let's Encrypt certificate
sudo certbot certonly --standalone -d yourdomain.com

# Copy certificate to docker/ssl/
```

### 3. Configure CORS

Edit `backend/src/server.js`:
```javascript
const corsOptions = {
  origin: ['https://yourdomain.com'],
  credentials: true
};
app.use(cors(corsOptions));
```

---

## 📱 DEVICE REGISTRATION FLOW

### Step 1: Client Scans QR Code

Device comes with QR code on packaging:
```
https://yourdomain.com/register?qr=DEVICE_ID&imei=352921019821045
```

### Step 2: Auto-fill Registration

System automatically fills:
- Device IMEI
- Device Model
- Serial Number (from QR)

### Step 3: Confirm & Activate

Client confirms device details and adds to account.

### Step 4: GPS Activation

Device sends first GPS signal → Status changes to "LIVE" → IMEI becomes locked.

---

## 🌍 LIVE GPS TRACKING

### Enable Real-time Updates

```javascript
// Frontend code
import io from 'socket.io-client';

const socket = io('http://localhost:5000');
socket.emit('subscribe-device', 'IMEI_HERE');

socket.on('gps-update', (data) => {
  // Update map marker with new GPS coordinates
  updateMarker(data.imei, data.latitude, data.longitude);
});
```

### GPS Data Processing

1. Device sends raw GPS data
2. Backend validates coordinates
3. Cleans data (outliers removed)
4. Stores in PostgreSQL
5. Caches in Redis
6. Broadcasts via WebSocket
7. Evaluates alerts
8. Updates real-time map

---

## 🔔 ALERT SYSTEM

### Configured Alerts

- **Speed Alert**: Triggers when speed > 120 km/h
- **Geofence Violation**: Entering/exiting defined areas
- **Route Deviation**: Deviating >50m from established route
- **Ignition ON/OFF**: Vehicle engine state changes
- **Towing Detection**: Abnormal movement detected
- **Tampering/Power Cut**: Device tampering detected

### Configure Alert Rules

```bash
# Via Admin Portal → Alert Management
# Or via API:

curl -X POST http://localhost:5000/api/admin/alerts/rules \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED_ALERT",
    "threshold": 100,
    "notification_method": "ALL"
  }'
```

---

## 💳 BILLING & RENEWALS

### Configure Payment Gateway

Edit `.env`:
```env
STRIPE_SECRET_KEY=sk_test_xxxxx
STRIPE_PUBLIC_KEY=pk_test_xxxxx
```

### Subscription Plans

Default plans (edit in `backend/src/services/billingService.js`):
- **Monthly**: $29.99/vehicle
- **Quarterly**: $79.99/vehicle
- **Yearly**: $249.99/vehicle

### Payment Due Notifications

System automatically sends notifications:
- 7 days before renewal (via email)
- 1 day before renewal (via SMS + email)
- On renewal date (auto-charge)
- If payment fails (3 retry attempts)

### Automated Cutoff

After 30 days of non-payment:
- Device status changes to "INACTIVE"
- Real-time tracking stops
- Client receives cutoff notice
- Reactivates upon successful payment

---

## 🛠️ INFRASTRUCTURE CONTROL (Admin)

### Manage TCP/UDP Ports

Admin Portal → Infrastructure Control → Port Allocation

Default ports:
- 5001-5003: TCP device connections
- 5004-5005: UDP device connections
- 5000: API server
- 3000: Client app
- 3001: Admin portal

### Add New Device Protocol

1. Go to Infrastructure Control
2. Click "Add Protocol"
3. Select port
4. Choose protocol (TCP/UDP/BOTH)
5. Upload/configure parser

### Device Protocol Management

Supported protocols:
- GPS-Tracker-Pro
- Fleet-Manager-5000
- TelemetryBox-X
- Custom (upload configuration)

---

## 📊 ADMIN DASHBOARD FEATURES

### Overview
- Total active clients
- Active devices (LIVE status)
- Recent alerts (last 24h)
- System health status
- Revenue overview

### Client Management
- View all clients
- Create new client account
- Manage subscriptions
- View payment history
- Reset client password

### Device Management
- View all registered devices
- Device status monitoring
- IMEI validation
- Device history
- Deactivate devices

### Billing Management
- View subscriptions
- Manage renewals
- Process manual payments
- View payment history
- Generate invoices

### Infrastructure Control
- TCP/UDP port allocation
- Device protocol management
- Server configuration
- Port status monitoring

---

## 🗺️ ADVANCED MAPPING FEATURES

### 3D Vehicle Markers

Markers automatically scale with map zoom:
```
Zoom Level 1: Large markers (visible from high altitude)
Zoom Level 10: Medium markers
Zoom Level 20: Detailed markers with vehicle direction
```

Marker rotation follows heading (direction of movement).

### Geofence Drawing Tools

1. **Polygon**: Click multiple points to draw custom shape
2. **Circle**: Drag to create circular geofence
3. **Route**: Import route from file or draw manually

### Route Geofencing

When route is set:
- System calculates center line
- Allows 50m deviation tolerance
- Alerts if vehicle deviates >50m
- Useful for delivery/transport routes

---

## 📱 ANDROID APP FEATURES

See `android-app/README.md` for detailed Android app setup.

Features:
- Login with biometric
- Live tracking map
- Device management
- Geofence creation
- Alert notifications
- Billing & renewal
- Offline capabilities

---

## 🚨 TROUBLESHOOTING

### Database Connection Error
```bash
# Check if PostgreSQL is running
docker-compose ps postgres

# Verify connection string in .env
# Restart database
docker-compose restart postgres
```

### WebSocket Connection Failed
```bash
# Check if backend is running
curl http://localhost:5000/health

# Verify Socket.io configuration
# Check CORS settings
```

### Device Not Appearing on Map
```bash
# 1. Check device is registered (IMEI)
# 2. Check device has active subscription
# 3. Verify device is sending GPS data
# 4. Check alert for any errors
```

### Payment Processing Error
```bash
# Verify Stripe keys in .env
# Check payment method is valid
# Review payment logs in admin panel
```

---

## 📈 PRODUCTION DEPLOYMENT

### AWS Deployment

```bash
# 1. Create RDS PostgreSQL instance
# 2. Create ElastiCache Redis cluster
# 3. Create ECS cluster
# 4. Push Docker images to ECR
# 5. Deploy backend, frontend, admin services
# 6. Configure ALB and Route53
```

### Environment Variables for Production

```env
NODE_ENV=production
DB_HOST=rds-endpoint.amazonaws.com
REDIS_HOST=elasticache-endpoint.amazonaws.com
JWT_SECRET=very_long_random_secure_key
STRIPE_SECRET_KEY=sk_live_xxxxx
TWILIO_ACCOUNT_SID=ACxxxxx
TWILIO_AUTH_TOKEN=authtoken
```

### SSL/TLS Certificate

```bash
# Install Let's Encrypt certificate
sudo certbot certonly --standalone -d yourdomain.com

# Configure Nginx to use certificate
# See docker/nginx.conf
```

---

## 📊 MONITORING & LOGGING

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f postgres
```

### Performance Monitoring

- CPU usage: `docker stats`
- Database queries: PostgreSQL slow log
- API response time: Check backend logs

---

## 🔄 DATABASE BACKUP & RESTORE

### Backup

```bash
docker-compose exec postgres pg_dump -U gps_admin gps_tracking > backup.sql
```

### Restore

```bash
docker-compose exec -T postgres psql -U gps_admin gps_tracking < backup.sql
```

---

## 📞 SUPPORT & DOCUMENTATION

- API Documentation: `API_DOCUMENTATION.md`
- Android Build Guide: `android-app/README.md`
- Database Schema: `DATABASE_SCHEMA.md`
- Architecture: `ARCHITECTURE.md`

---

## ✅ DEPLOYMENT CHECKLIST

- [ ] Change all default passwords
- [ ] Configure SSL/TLS certificates
- [ ] Set up email/SMS providers (Nodemailer, Twilio)
- [ ] Configure payment gateway (Stripe)
- [ ] Set up database backups
- [ ] Configure monitoring & logging
- [ ] Test all alert types
- [ ] Test payment processing
- [ ] Load test with multiple devices
- [ ] Security audit
- [ ] Go live!

---

## 🎉 SYSTEM IS READY

Your enterprise GPS tracking platform is now running!

**Next Steps:**
1. Create first admin account
2. Add test device
3. Verify GPS tracking
4. Create subscription plan
5. Test payment processing
6. Invite clients
7. Monitor system health

---

For detailed API endpoints, see `API_DOCUMENTATION.md`
