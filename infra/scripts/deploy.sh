#!/bin/bash

# Production Deployment Script with Rollback
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🚀 GPS Tracking SaaS Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Static IP: 3.108.114.12"
echo "TCP Port: 5023 (GPS Devices)"
echo "API Port: 5024 (REST + WebSocket)"
echo "Web Port: 5025 (Dashboard)"
echo -e "${GREEN}========================================${NC}"

# Load environment
if [ -f .env.production ]; then
    export $(cat .env.production | xargs)
else
    echo -e "${RED}❌ .env.production file not found!${NC}"
    exit 1
fi

# Function to rollback
rollback() {
    echo -e "${YELLOW}⚠️  Rolling back to previous version...${NC}"
    docker-compose -f infra/docker/docker-compose.yml down
    docker-compose -f infra/docker/docker-compose.yml up -d --no-build
    echo -e "${YELLOW}⚠️  Rollback complete${NC}"
    exit 1
}

# Backup current state
echo -e "${YELLOW}📦 Creating backup...${NC}"
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup database
docker exec gps-postgres pg_dump -U postgres gps_tracking > $BACKUP_DIR/db.sql || true

# Pull latest code
echo -e "${YELLOW}📦 Pulling latest code...${NC}"
git pull origin main || {
    echo -e "${RED}❌ Git pull failed${NC}"
    exit 1
}

# Stop existing containers
echo -e "${YELLOW}🛑 Stopping existing containers...${NC}"
docker-compose -f infra/docker/docker-compose.yml down || true

# Build images
echo -e "${YELLOW}🐳 Building Docker images...${NC}"
docker-compose -f infra/docker/docker-compose.yml build --no-cache || rollback

# Start services
echo -e "${YELLOW}▶️ Starting services...${NC}"
docker-compose -f infra/docker/docker-compose.yml up -d || rollback

# Wait for services
echo -e "${YELLOW}⏳ Waiting for services to start...${NC}"
sleep 15

# Health checks
echo -e "${YELLOW}🏥 Running health checks...${NC}"
FAILED=0

# Check TCP Server
if nc -z 3.108.114.12 5023 2>/dev/null; then
    echo -e "${GREEN}   ✅ TCP Server (5023) is listening${NC}"
else
    echo -e "${RED}   ❌ TCP Server (5023) failed${NC}"
    FAILED=1
fi

# Check Backend API
if curl -s http://3.108.114.12:5024/health > /dev/null; then
    echo -e "${GREEN}   ✅ Backend API (5024) is responding${NC}"
else
    echo -e "${RED}   ❌ Backend API (5024) failed${NC}"
    FAILED=1
fi

# Check Web Dashboard
if curl -s http://3.108.114.12:5025 > /dev/null; then
    echo -e "${GREEN}   ✅ Web Dashboard (5025) is responding${NC}"
else
    echo -e "${RED}   ❌ Web Dashboard (5025) failed${NC}"
    FAILED=1
fi

if [ $FAILED -eq 1 ]; then
    echo -e "${RED}❌ Health checks failed, rolling back...${NC}"
    rollback
fi

# Clean up old images
echo -e "${YELLOW}🧹 Cleaning up...${NC}"
docker image prune -f

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}📊 Access URLs:${NC}"
echo "   Web Dashboard: http://3.108.114.12:5025"
echo "   API Endpoint:  http://3.108.114.12:5024/api"
echo "   WebSocket:     ws://3.108.114.12:5024"
echo "   TCP Device:    3.108.114.12:5023"
echo ""
echo -e "${YELLOW}📋 Recent logs:${NC}"
docker-compose -f infra/docker/docker-compose.yml logs --tail=20
