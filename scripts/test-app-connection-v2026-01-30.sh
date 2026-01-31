#!/bin/bash

# Test Script: Prüft ob iOS-App mit Parse Server verbunden ist
# Verwendet Parse Server Logs und Netzwerk-Monitoring

set -e

UBUNTU_IP="${1:-192.168.178.24}"
UBUNTU_USER="${2:-io}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "App-Verbindung zu Parse Server prüfen"
echo "=========================================="
echo ""

echo -e "${BLUE}[1/4]${NC} Prüfe Parse Server Status..."
SERVER_STATUS=$(ssh "$UBUNTU_USER@$UBUNTU_IP" "cd ~/fin1-server && docker compose -f docker-compose.production.yml ps parse-server 2>&1 | grep -E 'Up|Restarting|Exited' | head -1" || echo "unbekannt")
echo "Parse Server Status: $SERVER_STATUS"

if echo "$SERVER_STATUS" | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} Parse Server läuft"
else
    echo -e "${RED}✗${NC} Parse Server läuft nicht!"
    exit 1
fi

echo ""
echo -e "${BLUE}[2/4]${NC} Prüfe Parse Server Health..."
HEALTH=$(curl -s http://$UBUNTU_IP:1338/parse/health 2>&1 || echo "failed")
if echo "$HEALTH" | grep -q "status"; then
    echo -e "${GREEN}✓${NC} Parse Server antwortet: $HEALTH"
else
    echo -e "${RED}✗${NC} Parse Server antwortet nicht"
    exit 1
fi

echo ""
echo -e "${BLUE}[3/4]${NC} Prüfe letzte Requests im Parse Server..."
echo "Letzte 10 Requests:"
ssh "$UBUNTU_USER@$UBUNTU_IP" "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs --tail=20 parse-server 2>&1 | grep -E 'POST|GET|PUT|DELETE' | tail -10" || echo "Keine Requests gefunden"

echo ""
echo -e "${BLUE}[4/4]${NC} Netzwerk-Verbindungen prüfen..."
echo "Aktive Verbindungen zu Parse Server:"
if command -v lsof &> /dev/null; then
    CONNECTIONS=$(sudo lsof -i -P 2>/dev/null | grep "$UBUNTU_IP:1338" || echo "Keine Verbindungen gefunden")
    if echo "$CONNECTIONS" | grep -q "ESTABLISHED"; then
        echo -e "${GREEN}✓${NC} Aktive Verbindung gefunden:"
        echo "$CONNECTIONS" | head -5
    else
        echo -e "${YELLOW}⚠${NC} Keine aktive Verbindung (App läuft möglicherweise nicht oder ist nicht verbunden)"
    fi
else
    echo "lsof nicht verfügbar - überspringe Netzwerk-Check"
fi

echo ""
echo "=========================================="
echo "Nächste Schritte:"
echo "=========================================="
echo ""
echo "1. App im Simulator starten"
echo "2. Xcode Console öffnen (⌘⇧Y)"
echo "3. Nach '✅ Parse Live Query connected' suchen"
echo "4. Parse Server Logs überwachen:"
echo "   ssh $UBUNTU_USER@$UBUNTU_IP 'cd ~/fin1-server && docker compose -f docker-compose.production.yml logs -f parse-server'"
echo ""
