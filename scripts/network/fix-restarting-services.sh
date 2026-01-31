#!/bin/bash

# FIN1 Fix Restarting Services Script
# Behebt Services die im "restarting" Status sind

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "FIN1 Fix Restarting Services"
echo "=========================================="
echo ""

# Check for restarting services
RESTARTING_SERVICES=$(docker compose -f docker-compose.production.yml ps | grep "restarting" | awk '{print $1}')

if [ -z "$RESTARTING_SERVICES" ]; then
    echo -e "${GREEN}✓ No services in restarting status${NC}"
    exit 0
fi

echo -e "${YELLOW}Found restarting services:${NC}"
echo "$RESTARTING_SERVICES"
echo ""

# Fix each restarting service
for service in $RESTARTING_SERVICES; do
    echo "----------------------------------------"
    echo "Fixing: $service"
    echo "----------------------------------------"
    
    # Show logs
    echo "Recent logs:"
    docker compose -f docker-compose.production.yml logs --tail=20 "$service"
    echo ""
    
    # Stop service
    echo "Stopping $service..."
    docker compose -f docker-compose.production.yml stop "$service"
    sleep 2
    
    # Check dependencies
    case "$service" in
        nginx)
            echo "Checking dependencies for nginx..."
            docker compose -f docker-compose.production.yml ps parse-server | grep -q "Up" || {
                echo "Starting parse-server (dependency)..."
                docker compose -f docker-compose.production.yml up -d parse-server
                sleep 10
            }
            ;;
        market-data)
            echo "Checking dependencies for market-data..."
            docker compose -f docker-compose.production.yml ps redis | grep -q "Up" || {
                echo "Starting redis (dependency)..."
                docker compose -f docker-compose.production.yml up -d redis
                sleep 5
            }
            docker compose -f docker-compose.production.yml ps parse-server | grep -q "Up" || {
                echo "Starting parse-server (dependency)..."
                docker compose -f docker-compose.production.yml up -d parse-server
                sleep 10
            }
            ;;
    esac
    
    # Start service
    echo "Starting $service..."
    docker compose -f docker-compose.production.yml up -d "$service"
    sleep 5
    
    # Check status
    STATUS=$(docker compose -f docker-compose.production.yml ps "$service" | tail -1 | awk '{print $6}')
    if [ "$STATUS" = "Up" ]; then
        echo -e "${GREEN}✓ $service is now running${NC}"
    else
        echo -e "${RED}✗ $service is still having issues${NC}"
        echo "Check logs: docker compose -f docker-compose.production.yml logs $service"
    fi
    echo ""
done

echo "=========================================="
echo "Final Status"
echo "=========================================="
docker compose -f docker-compose.production.yml ps
echo ""
