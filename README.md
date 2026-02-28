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
Step 1: Create Lightsail Instance (if not already done)

Go to: https://lightsail.aws.amazon.com
Click Create instance
Choose location → Asia Pacific (Mumbai) or your closest region
Select platform → Linux/Unix
Select blueprint → OS Only → Ubuntu 22.04 LTS
Choose instance plan → 2 GB RAM, 1 vCPU, 60 GB SSD, 3 TB transfer (~$10/month)
Instance name → e.g. gps-saas-prod
Click Create instance

Wait ~1–2 minutes until status = Running.
Step 2: Attach Static IP (Important for devices)
Your IP must stay the same so devices always connect to 3.108.114.12:5023.

In Lightsail → select your instance → Networking tab
Click Create static IP
Choose same region
Attach it to your instance
Note the IP → it should now be 3.108.114.12 (or whatever AWS gave you — update your GT06 devices if different)

Step 3: Connect to Instance via SSH

In Lightsail → your instance → Connect tab
Use browser-based SSH (easiest) or download key and connect via terminal:Bashchmod 400 LightsailDefaultKey.pem
ssh -i LightsailDefaultKey.pem ubuntu@3.108.114.12

Step 4: Prepare the Server (Install Git, Docker, Docker Compose)
Run these commands one by one:
Bash# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y git docker.io docker-compose unzip curl

# Add current user to docker group (so no sudo needed for docker)
sudo usermod -aG docker ubuntu

# Apply group change without logout
newgrp docker
Step 5: Clone Your Repository
Bash# Clone your GitHub repo (replace YOUR_USERNAME)
git clone https://github.com/YOUR_USERNAME/gps-tracking-saas.git

# Enter project folder
cd gps-tracking-saas
Step 6: Configure .env File
Bash# Copy example to real file
cp .env.example .env

# Edit it
nano .env
Make sure these key lines are correct:
textDATABASE_URL=postgres://user:your_strong_password@postgres:5432/gps_db
REDIS_URL=redis://redis:6379

CESIUM_TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiI1NzhmZTZlNy1mNDMwLTQwZWMtOWQ0Ny1kNTM3ZTZkZGY3NDkiLCJpZCI6Mzk1NTI5LCJpYXQiOjE3NzIyMTg3MjF9.KJuxvYyw7CSPNvOzmpFUGYNzeWxN-e-WOnOuikGRKZs

STATIC_IP=3.108.114.12
Save and exit (Ctrl+O → Enter → Ctrl+X).
Step 7: Deploy with Docker Compose
Bash# Build and start all services in background
docker-compose up -d --build
This will:

Build tcp-server, backend, web-frontend
Start PostgreSQL → auto-run schema.sql
Start Redis, TCP server (5023), API (5024), Web (5025), Nginx (80), monitoring tools

Wait 1–2 minutes for everything to start.
Step 8: Open Firewall Ports in Lightsail
Go to Lightsail console → your instance → Networking tab → Firewall → + Add rule
Add these (TCP protocol):








































PortPurposeSource5023GT06 device connectionsAnywhere (0.0.0.0/0)5024API + WebSocketAnywhere (0.0.0.0/0)5025Direct web dashboard accessAnywhere (0.0.0.0/0)80HTTP (Nginx proxy)Anywhere (0.0.0.0/0)443HTTPS (after certbot)Anywhere (0.0.0.0/0)5027–5030Monitoring (Grafana etc.)Your IP only (for security)
Click Save.
(Optional but recommended: restrict monitoring ports to your IP only.)
Step 9: Add HTTPS (Very Important – Cesium requires it)
Bash# Install certbot
sudo apt install -y certbot python3-certbot-nginx

# If you have a domain (recommended)
sudo certbot --nginx -d yourdomain.com

# If no domain (temporary test)
# Use self-signed or skip for now (Cesium may show warnings)
After certbot:

Nginx will be updated to use HTTPS
Restart nginx container:Bashdocker restart gps-nginx

Step 10: Verify Everything is Running
Check containers:
Bashdocker ps
Should show ~10 containers running (postgres, redis, tcp-server, backend, web-frontend, nginx, prometheus, grafana, adminer, portainer).
Test endpoints:
Bash# Health check API
curl http://localhost:5024/health

# Web dashboard (from your browser)
http://3.108.114.12:5025

# Or via Nginx proxy
http://3.108.114.12

# Grafana (monitoring)
http://3.108.114.12:5028   (default login: admin / admin)
Step 11: Set Up Automatic Backups & Monitoring
Add daily backup cron:
Bashcrontab -e
Add this line:
text0 3 * * * cd /home/ubuntu/gps-tracking-saas && ./infra/scripts/backup.sh
Check monitoring:

Open Grafana → http://3.108.114.12:5028
Add Prometheus datasource → http://prometheus:9090
Import dashboards for Docker, Node.js, PostgreSQL

Step 12: Connect Real Devices & Test

Configure your GT06 device:
Server IP: 3.108.114.12
Port: 5023
Protocol: TCP

Watch logs:Bashdocker logs -f gps-tcp
If data arrives → you will see parsing logs and DB updates.
Open web dashboard → should show live position with 3D marker rotation.
Test command (ignition off) via API or dashboard.

Troubleshooting Checklist





























ProblemCommand / FixDocker not startingdocker logs <container-name> (e.g. docker logs gps-tcp)No data from deviceCheck Lightsail firewall port 5023 TCP open + device configCesium map blankMust use HTTPS + correct token in .env & frontend codeHigh memory usageUpgrade to 4 GB plan if >50 devicesDatabase connection failedCheck DATABASE_URL in .env (use container name postgres)
Your system is now live on AWS Lightsail.
If you run into any specific error (copy-paste logs), reply with it — I’ll help fix immediately.
Good luck with your pilot! Let me know when the first device connects. 🚀
