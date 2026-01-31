#!/bin/bash

# FIN1 Service Diagnostics Script
# Diagnostiziert Probleme mit Services und zeigt detaillierte Informationen

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "=========================================="
echo "FIN1 Service Diagnostics"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if docker compose is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "docker-compose.production.yml" ]; then
    echo -e "${RED}Error: docker-compose.production.yml not found${NC}"
    echo "Please run this script from the project root directory"
    exit 1
fi

echo "1. Service Status Overview"
echo "----------------------------------------"
docker compose -f docker-compose.production.yml ps
echo ""

echo "2. Services with Issues"
echo "----------------------------------------"
RESTARTING=$(docker compose -f docker-compose.production.yml ps | grep "restarting" | wc -l)
if [ "$RESTARTING" -gt 0 ]; then
    echo -e "${YELLOW}Warning: $RESTARTING service(s) in 'restarting' status${NC}"
    docker compose -f docker-compose.production.yml ps | grep "restarting"
else
    echo -e "${GREEN}✓ No services in restarting status${NC}"
fi
echo ""

echo "3. Health Check Status"
echo "----------------------------------------"
SERVICES=("parse-server:1337" "nginx:80" "market-data:8080" "notification-service:8081" "analytics-service:8082")

for service_port in "${SERVICES[@]}"; do
    IFS=':' read -r service port <<< "$service_port"
    if curl -f -s "http://localhost:$port/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $service (port $port): Healthy${NC}"
    else
        echo -e "${RED}✗ $service (port $port): Unhealthy or not responding${NC}"
    fi
done
echo ""

echo "4. Recent Errors in Logs"
echo "----------------------------------------"
for service in parse-server nginx market-data notification-service analytics-service; do
    ERRORS=$(docker compose -f docker-compose.production.yml logs --tail=50 "$service" 2>&1 | grep -i "error\|fatal\|exception" | head -5)
    if [ -n "$ERRORS" ]; then
        echo -e "${YELLOW}Errors in $service:${NC}"
        echo "$ERRORS"
        echo ""
    fi
done

echo "5. Network Configuration"
echo "----------------------------------------"
echo "Ubuntu Server IP:"
hostname -I | awk '{print $1}'
echo ""
echo "Docker Network:"
docker network inspect fin1-network 2>/dev/null | grep -A 5 "Subnet" || echo "Network not found"
echo ""

echo "6. Resource Usage"
echo "----------------------------------------"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -10
echo ""

echo "7. Container Restart Counts"
echo "----------------------------------------"
docker compose -f docker-compose.production.yml ps --format json | jq -r '.[] | "\(.Name): \(.RestartCount) restarts"' 2>/dev/null || \
docker compose -f docker-compose.production.yml ps | grep -E "NAME|restarting|Up"
echo ""

echo "=========================================="
echo "Diagnostics Complete"
echo "=========================================="
