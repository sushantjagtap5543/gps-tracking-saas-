#!/bin/bash
set -e

echo "🚀 GPS Tracking SaaS - DEPLOYMENT STARTED"

# Pull latest code
git pull origin main

# Build & start
docker-compose down
docker-compose pull
docker-compose up -d

# Wait for services
sleep 20

# Health checks
echo "✅ Checking services..."
docker-compose ps

# Test TCP
echo "🧪 Testing TCP port 5001..."
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/localhost/5001' && echo "TCP OK" || echo "TCP FAILED"

# Test API
curl -f http://localhost:3000/health && echo "API OK" || echo "API FAILED"

echo "🎉 DEPLOYMENT COMPLETE!"
echo "🌐 Admin: http://localhost:8080"
echo "📡 TCP: 5001 | API: 3000"
echo "💾 DB: localhost:5432"
