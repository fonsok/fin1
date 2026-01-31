#!/bin/bash

# FIN1 Parse Server URL Configuration Script
# Konfiguriert Parse Server URLs für lokales Netzwerk

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "FIN1 Parse Server URL Configuration"
echo "=========================================="
echo ""

# Check if .env file exists
if [ ! -f "backend/.env" ]; then
    echo -e "${YELLOW}Warning: backend/.env not found${NC}"
    echo "Creating from env.example..."
    cp backend/env.example backend/.env
fi

# Get Ubuntu server IP
echo "Detecting Ubuntu server IP..."
UBUNTU_IP=$(hostname -I | awk '{print $1}')

if [ -z "$UBUNTU_IP" ]; then
    echo "Could not auto-detect IP. Please enter Ubuntu server IP:"
    read -r UBUNTU_IP
fi

echo -e "${GREEN}Using IP: $UBUNTU_IP${NC}"
echo ""

# Backup .env file
BACKUP_FILE="backend/.env.backup.$(date +%Y%m%d_%H%M%S)"
cp backend/.env "$BACKUP_FILE"
echo "Backup created: $BACKUP_FILE"
echo ""

# Update Parse Server URLs
echo "Updating Parse Server URLs..."

# Update PARSE_SERVER_PUBLIC_SERVER_URL
if grep -q "PARSE_SERVER_PUBLIC_SERVER_URL=" backend/.env; then
    sed -i.bak "s|PARSE_SERVER_PUBLIC_SERVER_URL=.*|PARSE_SERVER_PUBLIC_SERVER_URL=http://$UBUNTU_IP:1338/parse|g" backend/.env
    echo "✓ Updated PARSE_SERVER_PUBLIC_SERVER_URL"
else
    echo "PARSE_SERVER_PUBLIC_SERVER_URL=http://$UBUNTU_IP:1338/parse" >> backend/.env
    echo "✓ Added PARSE_SERVER_PUBLIC_SERVER_URL"
fi

# Update PARSE_SERVER_LIVE_QUERY_SERVER_URL
if grep -q "PARSE_SERVER_LIVE_QUERY_SERVER_URL=" backend/.env; then
    sed -i.bak "s|PARSE_SERVER_LIVE_QUERY_SERVER_URL=.*|PARSE_SERVER_LIVE_QUERY_SERVER_URL=ws://$UBUNTU_IP:1338/parse|g" backend/.env
    echo "✓ Updated PARSE_SERVER_LIVE_QUERY_SERVER_URL"
else
    echo "PARSE_SERVER_LIVE_QUERY_SERVER_URL=ws://$UBUNTU_IP:1338/parse" >> backend/.env
    echo "✓ Added PARSE_SERVER_LIVE_QUERY_SERVER_URL"
fi

# Update CORS if needed
if grep -q "ALLOWED_ORIGINS=" backend/.env; then
    # Check if local network is already in ALLOWED_ORIGINS
    if ! grep -q "192.168.178" backend/.env; then
        # Add local network to ALLOWED_ORIGINS
        sed -i.bak "s|ALLOWED_ORIGINS=\(.*\)|ALLOWED_ORIGINS=\1,http://192.168.178.0/24|g" backend/.env
        echo "✓ Updated ALLOWED_ORIGINS"
    fi
else
    echo "ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,http://192.168.178.0/24" >> backend/.env
    echo "✓ Added ALLOWED_ORIGINS"
fi

# Clean up backup files created by sed
rm -f backend/.env.bak

echo ""
echo "=========================================="
echo "Configuration Updated"
echo "=========================================="
echo ""
echo "Updated values:"
grep "PARSE_SERVER_PUBLIC_SERVER_URL\|PARSE_SERVER_LIVE_QUERY_SERVER_URL\|ALLOWED_ORIGINS" backend/.env
echo ""
echo "Next steps:"
echo "1. Restart Parse Server: docker compose -f docker-compose.production.yml restart parse-server"
echo "2. Test connection: curl http://$UBUNTU_IP:1338/parse/health"
echo ""
