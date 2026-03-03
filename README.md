# 🚀 ENTERPRISE GPS TRACKING SaaS PLATFORM

**Production-Ready GPS Vehicle Tracking System with Admin & Client Portals**

---

## ✨ SYSTEM FEATURES

### 🔐 **Authentication & Authorization**
✅ Unified landing page (login + forgot password + demo hub)  
✅ Admin/Client role-based access  
✅ JWT token authentication  
✅ Secure password hashing  
✅ QR code based device registration  

### 📱 **Device Management**
✅ IMEI-based device identification  
✅ Immutable IMEI fields on LIVE status  
✅ No hardware model names in client UI  
✅ Device protocol management (TCP/UDP)  
✅ Infrastructure control (port allocation)  
✅ Multi-device support  

### 🗺️ **Real-time GPS Tracking**
✅ Sub-second GPS data processing  
✅ WebSocket real-time updates  
✅ 3D vehicle markers with zoom scaling  
✅ Live vehicle location updates  
✅ Speed and heading tracking  
✅ Direction-based marker rotation  

### 🎯 **Geofencing & Alerts**
✅ Custom polygon geofence drawing  
✅ Circle geofence creation  
✅ Route geofencing (snap to roads)  
✅ 50m deviation alerts  
✅ Entry/exit notifications  
✅ Speed limit alerts  
✅ Ignition ON/OFF detection  
✅ Towing detection  
✅ Tampering/Power cut alerts  

### 💳 **Billing & Subscriptions**
✅ Vehicle subscription renewal  
✅ Flexible subscription plans (monthly/quarterly/yearly)  
✅ Stripe payment integration  
✅ Automated payment due notifications  
✅ Automated device cutoff for unpaid subscriptions  
✅ Invoice generation  
✅ Payment history tracking  

### 📊 **Admin Dashboard**
✅ God mode control over all system aspects  
✅ Client management  
✅ Device registry & monitoring  
✅ Alert rule configuration  
✅ Subscription management  
✅ Infrastructure control (TCP/UDP port allocation)  
✅ System health KPIs  
✅ Revenue analytics  

### 📱 **Client Portal**
✅ Live tracking dashboard  
✅ Device management (add/remove/view)  
✅ Geofence builder  
✅ Alert history & management  
✅ Trip reports & analytics  
✅ Subscription status  
✅ Payment management  
✅ User profile management  

### 📱 **Mobile App (Android)**
✅ 100% feature parity with web  
✅ Offline capabilities  
✅ Push notifications  
✅ Biometric authentication  
✅ Background GPS tracking  

### 🔔 **Notification System**
✅ Email notifications  
✅ SMS notifications  
✅ Push notifications  
✅ In-app alerts  
✅ Multi-channel notification support  

---

## 🛠️ TECHNOLOGY STACK

### **Backend**
- Node.js 18+
- Express.js
- PostgreSQL 15
- Redis 7
- Socket.io (WebSocket)
- Stripe API
- Twilio (SMS)
- Nodemailer (Email)

### **Frontend**
- React 18
- React Router v6
- TailwindCSS
- Leaflet (Maps)
- Zustand (State)
- Axios
- Socket.io Client

### **Mobile**
- React Native / Kotlin
- Firebase Cloud Messaging
- SQLite (Offline)

### **Infrastructure**
- Docker & Docker Compose
- Nginx (Reverse Proxy)
- PostgreSQL with Replication
- Redis Cluster
- AWS compatible

---

## 🚀 QUICK START

### Requirements
- Docker & Docker Compose
- Git
- 4GB RAM minimum
- 20GB disk space

### 1. Clone & Extract
```bash
unzip gps-tracking-enterprise.zip
cd gps-tracking-enterprise
```

### 2. Configure
```bash
cp .env.example .env
# Edit .env with your settings
nano .env
```

### 3. Start Services
```bash
docker-compose up -d
```

### 4. Access Applications
- Client App: http://localhost:3000
- Admin Portal: http://localhost:3001
- API: http://localhost:5000
- Nginx: http://localhost

---

## 📋 FIRST RUN SETUP

### Create Admin User
```bash
docker-compose exec postgres psql -U gps_admin -d gps_tracking
INSERT INTO users (email, password, company_name, phone, role, is_active)
VALUES ('admin@gpstracking.com', '$2a$10$...', 'GPS Tracking', '+1234567890', 'admin', true);
```

### Create Test Device
1. Login to Admin Portal
2. Go to Device Management
3. Register device with IMEI: 352921019821045

### Send Test GPS Data
```bash
curl -X POST http://localhost:5000/api/gps/update \
  -H "Content-Type: application/json" \
  -d '{
    "imei": "352921019821045",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "speed": 45,
    "heading": 180,
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }'
```

---

## 📁 PROJECT STRUCTURE

```
gps-tracking-enterprise/
├── backend/                 # Node.js API server
│   ├── src/
│   │   ├── server.js       # Main server
│   │   ├── controllers/    # Business logic
│   │   ├── services/       # Utilities
│   │   ├── models/         # Data models
│   │   ├── routes/         # API endpoints
│   │   ├── middleware/     # Auth & validation
│   │   ├── workers/        # Background jobs
│   │   └── utils/          # Helpers
│   ├── package.json
│   └── Dockerfile
│
├── frontend/                # React client app
│   ├── src/
│   │   ├── pages/          # Page components
│   │   ├── components/     # Reusable components
│   │   ├── services/       # API & WebSocket
│   │   └── stores/         # State management
│   └── package.json
│
├── admin/                   # React admin portal
│   ├── src/
│   │   ├── pages/
│   │   ├── components/
│   │   └── services/
│   └── package.json
│
├── android-app/            # React Native app
│   └── app/
│       ├── src/
│       ├── build.gradle
│       └── AndroidManifest.xml
│
├── database/               # PostgreSQL
│   ├── schema.sql          # Database schema
│   ├── migrations/         # DB migrations
│   └── seeders/            # Initial data
│
├── docker/                 # Docker config
│   ├── nginx.conf          # Nginx reverse proxy
│   └── docker-compose.yml
│
├── docs/                   # Documentation
│   ├── API_DOCUMENTATION.md
│   ├── DATABASE_SCHEMA.md
│   ├── ARCHITECTURE.md
│   ├── SETUP_GUIDE.md
│   └── DEPLOYMENT_GUIDE.md
│
├── .env.example            # Environment template
├── docker-compose.yml      # Docker stack
├── README.md               # This file
└── SETUP_GUIDE.md          # Setup instructions

```

---

## 🔑 KEY ENDPOINTS

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user
- `POST /api/auth/forgot-password` - Reset password

### Devices
- `GET /api/devices` - List devices
- `POST /api/devices/register` - Register new device
- `GET /api/devices/:id` - Get device details

### GPS Tracking
- `POST /api/gps/update` - Send GPS data
- `GET /api/gps/:imei` - Get latest GPS data

### Geofences
- `POST /api/geofence/create` - Create geofence
- `GET /api/geofence/:id` - Get geofence
- `DELETE /api/geofence/:id` - Delete geofence

### Alerts
- `GET /api/alerts` - Get alerts
- `POST /api/alerts/rules` - Create alert rule
- `PUT /api/alerts/:id/read` - Mark as read

### Billing
- `GET /api/billing/subscription/:device_id` - Get subscription
- `POST /api/billing/payment` - Process payment

### Admin
- `GET /api/admin/dashboard` - Admin dashboard stats
- `GET /api/admin/clients` - List all clients
- `GET /api/admin/infrastructure/ports` - Get port allocations

---

## 🔒 SECURITY FEATURES

✅ JWT token authentication  
✅ Password hashing (bcryptjs)  
✅ HTTPS/TLS encryption  
✅ Role-based access control  
✅ Device IMEI validation  
✅ Rate limiting  
✅ Input validation  
✅ CORS configuration  
✅ Audit logging  
✅ Secure payment processing  

---

## 📊 DATABASE SCHEMA

**Key Tables:**
- `users` - Admin & Client accounts
- `devices` - Device registry (IMEI locked)
- `gps_locations` - Raw GPS data
- `geofences` - Polygon & circle boundaries
- `alerts` - Alert definitions & instances
- `subscriptions` - Vehicle subscriptions
- `payments` - Payment records
- `infrastructure_ports` - TCP/UDP allocations
- `device_protocols` - Device protocol definitions

**Key Constraints:**
- IMEI locked on LIVE status
- No hardware models in client UI
- Immutable subscription records
- Audit trail for all changes

---

## 🚀 DEPLOYMENT

### Docker (Recommended)
```bash
docker-compose up -d
```

### AWS ECS
See DEPLOYMENT_GUIDE.md for detailed AWS setup

### Manual Setup
See SETUP_GUIDE.md for manual deployment

---

## 📖 DOCUMENTATION

- **SETUP_GUIDE.md** - Complete setup instructions
- **DEPLOYMENT_GUIDE.md** - Production deployment
- **API_DOCUMENTATION.md** - API reference
- **DATABASE_SCHEMA.md** - Database structure
- **ARCHITECTURE.md** - System architecture
- **android-app/README.md** - Android app guide

---

## ✅ SYSTEM REQUIREMENTS

**Minimum:**
- RAM: 4GB
- CPU: 2 cores
- Disk: 20GB
- OS: Linux, Mac, Windows

**Recommended:**
- RAM: 8GB
- CPU: 4 cores
- Disk: 100GB
- Database: AWS RDS
- Cache: AWS ElastiCache

---

## 🆘 TROUBLESHOOTING

### Services not starting
```bash
docker-compose logs -f
docker-compose down -v && docker-compose up -d
```

### Database connection error
```bash
docker-compose restart postgres
```

### WebSocket connection failed
```bash
# Check backend is running
curl http://localhost:5000/health
```

---

## 📞 SUPPORT

For detailed documentation and guides, see the `docs/` folder.

---

## 📄 LICENSE

Enterprise GPS Tracking Platform ©2024

---

## 🎯 NEXT STEPS

1. ✅ Start services: `docker-compose up -d`
2. ✅ Create admin account (see SETUP_GUIDE.md)
3. ✅ Register test device
4. ✅ Send GPS data
5. ✅ View on dashboard
6. ✅ Configure subscriptions
7. ✅ Setup payment gateway
8. ✅ Go live!

---

**System Status: ✅ PRODUCTION READY**

Version: 1.0.0
Last Updated: 2024
