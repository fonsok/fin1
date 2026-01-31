#!/bin/bash
# FIN1 Quick Deployment - All-in-One Script
# Automatisiert den gesamten Deployment-Prozess

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}=========================================="
echo "FIN1 Quick Deployment"
echo "==========================================${NC}"
echo ""
echo -e "${YELLOW}Hinweis:${NC} Für optimale Ergebnisse:"
echo "  - Fritzbox: Feste IP für Ubuntu vergeben"
echo "  - Siehe: scripts/FRITZBOX_SETUP-v2026-01-30.md"
echo ""

# Step 1: Find Ubuntu server
echo -e "${YELLOW}[1/5]${NC} Ubuntu-Server im Netzwerk suchen..."
if [ -z "$1" ]; then
    echo "Möchten Sie automatisch nach Ubuntu-Servern suchen? (y/n)"
    read -p "> " AUTO_FIND
    if [ "$AUTO_FIND" = "y" ]; then
        "$SCRIPT_DIR/find-ubuntu-server-v2026-01-30.sh"
        echo ""
        read -p "Ubuntu Server IP eingeben: " UBUNTU_IP
    else
        read -p "Ubuntu Server IP eingeben: " UBUNTU_IP
    fi
else
    UBUNTU_IP="$1"
fi

if [ -z "$UBUNTU_IP" ]; then
    echo -e "${RED}Fehler: Keine IP-Adresse angegeben${NC}"
    exit 1
fi

read -p "Ubuntu Benutzername (Standard: $(whoami)): " UBUNTU_USER
UBUNTU_USER=${UBUNTU_USER:-$(whoami)}

echo -e "${GREEN}✓${NC} Server: $UBUNTU_USER@$UBUNTU_IP"
echo ""

# Step 2: Test connection
echo -e "${YELLOW}[2/5]${NC} Verbindung testen..."
if ! ping -c 1 -W 2 "$UBUNTU_IP" &> /dev/null; then
    echo -e "${RED}✗${NC} Server nicht erreichbar!"
    exit 1
fi
echo -e "${GREEN}✓${NC} Server ist erreichbar"
echo ""

# Step 3: Setup Ubuntu (if needed)
echo -e "${YELLOW}[3/5]${NC} Ubuntu-Setup prüfen..."
if ! ssh -o ConnectTimeout=5 "$UBUNTU_USER@$UBUNTU_IP" "command -v docker &> /dev/null" 2>/dev/null; then
    echo -e "${YELLOW}Docker nicht gefunden. Setup wird ausgeführt...${NC}"
    "$SCRIPT_DIR/deploy-to-ubuntu-v2026-01-30.sh" "$UBUNTU_IP" "$UBUNTU_USER"
    echo ""
    echo -e "${YELLOW}WICHTIG: Bitte auf Ubuntu 'newgrp docker' ausführen!${NC}"
    read -p "Wurde 'newgrp docker' auf Ubuntu ausgeführt? (y/n): " DOCKER_READY
    if [ "$DOCKER_READY" != "y" ]; then
        echo -e "${YELLOW}Bitte auf Ubuntu 'newgrp docker' ausführen und erneut starten.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} Docker ist installiert"
fi
echo ""

# Step 4: Deploy files
echo -e "${YELLOW}[4/5]${NC} Dateien deployen..."
"$SCRIPT_DIR/deploy-to-ubuntu-v2026-01-30.sh" "$UBUNTU_IP" "$UBUNTU_USER"
echo ""

# Step 5: Configure and start
echo -e "${YELLOW}[5/5]${NC} Server konfigurieren und starten..."
echo ""
echo -e "${YELLOW}WICHTIG: Bitte Passwörter in .env ändern!${NC}"
echo ""
read -p "Möchten Sie jetzt die .env-Datei auf Ubuntu bearbeiten? (y/n): " EDIT_ENV
if [ "$EDIT_ENV" = "y" ]; then
    ssh -t "$UBUNTU_USER@$UBUNTU_IP" "cd ~/fin1-server/backend && nano .env"
fi

echo ""
read -p "Server jetzt starten? (y/n): " START_SERVER
if [ "$START_SERVER" = "y" ]; then
    echo -e "${YELLOW}Server wird gestartet...${NC}"
    ssh "$UBUNTU_USER@$UBUNTU_IP" "cd ~/fin1-server && docker compose -f docker-compose.production.yml up -d"

    echo ""
    echo -e "${YELLOW}Warte auf Services...${NC}"
    sleep 10

    echo ""
    echo -e "${YELLOW}Service-Status:${NC}"
    ssh "$UBUNTU_USER@$UBUNTU_IP" "cd ~/fin1-server && docker compose ps"

    echo ""
    echo -e "${YELLOW}Health Check:${NC}"
    sleep 5
    curl -s "http://$UBUNTU_IP/health" || echo -e "${YELLOW}Health endpoint noch nicht verfügbar${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Deployment abgeschlossen!"
echo "==========================================${NC}"
echo ""
echo "Server Details:"
echo "  IP: $UBUNTU_IP"
echo "  Parse API: http://$UBUNTU_IP:1338/parse"
echo "  Dashboard: http://$UBUNTU_IP:1338/dashboard"
echo "  Health: http://$UBUNTU_IP/health"
echo ""
echo "Nützliche Befehle:"
echo "  Logs anzeigen: ssh $UBUNTU_USER@$UBUNTU_IP 'cd ~/fin1-server && docker compose logs -f'"
echo "  Services stoppen: ssh $UBUNTU_USER@$UBUNTU_IP 'cd ~/fin1-server && docker compose down'"
echo "  Services starten: ssh $UBUNTU_USER@$UBUNTU_IP 'cd ~/fin1-server && docker compose up -d'"
echo ""
