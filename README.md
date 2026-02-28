# GPS Tracking SaaS (Final Live System)

## Setup
1. Copy .env.example to .env, fill vars (DB, Redis, Cesium token).
2. Run `docker-compose up -d` (builds & starts all).
3. Access:
   - TCP devices: 3.108.114.12:5023
   - API: http://3.108.114.12:5024
   - Web: http://3.108.114.12:5025
   - Nginx proxy: http://3.108.114.12 (unified)
4. Android: Build APK in Android Studio.
5. Deploy to Lightsail: SSH in, git clone, ./infra/scripts/deploy.sh.

## Test Live Data
- Configure GT06 device to server IP:port.
- Send sample command via API POST /api/commands.

See docs/master-plan.md for full plan.
