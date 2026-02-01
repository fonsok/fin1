#!/bin/bash
# FIN1 Deployment Script - Kopiert Dateien auf Ubuntu-Server
# Usage: ./deploy-to-ubuntu-v2026-01-30.sh [ubuntu-ip-or-hostname] [ubuntu-user]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"

# Get Ubuntu server details
if [ -z "$1" ]; then
    echo -e "${YELLOW}FIN1 Deployment auf Ubuntu-Server${NC}"
    echo ""
    echo "Bitte Ubuntu-Server IP-Adresse oder Hostname eingeben:"
    read -p "Ubuntu IP/Hostname: " UBUNTU_HOST
else
    UBUNTU_HOST="$1"
fi

if [ -z "$2" ]; then
    echo "Bitte Ubuntu-Benutzername eingeben (Standard: $(whoami)):"
    read -p "Ubuntu User: " UBUNTU_USER
    UBUNTU_USER=${UBUNTU_USER:-$(whoami)}
else
    UBUNTU_USER="$2"
fi

REMOTE_DIR="~/fin1-server"

echo -e "\n${BLUE}=========================================="
echo "FIN1 Deployment"
echo "==========================================${NC}"
echo "Ubuntu Server: $UBUNTU_USER@$UBUNTU_HOST"
echo "Remote Verzeichnis: $REMOTE_DIR"
echo ""
echo -e "${YELLOW}Hinweis:${NC} Für optimale Konfiguration:"
echo "  - Fritzbox: Feste IP für Ubuntu vergeben"
echo "  - Siehe: scripts/FRITZBOX_SETUP.md"
echo ""

# Test SSH connection
echo -e "${YELLOW}[1/6]${NC} SSH-Verbindung testen..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$UBUNTU_USER@$UBUNTU_HOST" exit 2>/dev/null; then
    echo -e "${RED}✗${NC} SSH-Verbindung fehlgeschlagen!"
    echo ""
    echo "Bitte SSH-Zugriff einrichten:"
    echo "1. Auf Ubuntu: sudo systemctl enable ssh && sudo systemctl start ssh"
    echo "2. SSH-Key generieren (falls nicht vorhanden): ssh-keygen -t ed25519"
    echo "3. SSH-Key kopieren: ssh-copy-id $UBUNTU_USER@$UBUNTU_HOST"
    echo ""
    read -p "SSH-Key jetzt kopieren? (y/n): " COPY_KEY
    if [ "$COPY_KEY" = "y" ]; then
        ssh-copy-id "$UBUNTU_USER@$UBUNTU_HOST" || {
            echo -e "${RED}Fehler beim Kopieren des SSH-Keys. Bitte manuell einrichten.${NC}"
            exit 1
        }
    else
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} SSH-Verbindung erfolgreich"
fi

# Check if setup script was run
echo -e "\n${YELLOW}[2/6]${NC} Prüfe ob Setup-Skript ausgeführt wurde..."
if ! ssh "$UBUNTU_USER@$UBUNTU_HOST" "command -v docker &> /dev/null"; then
    echo -e "${YELLOW}Docker nicht gefunden. Setup-Skript wird ausgeführt...${NC}"
    scp "$SCRIPT_DIR/setup-ubuntu-server-v2026-01-30.sh" "$UBUNTU_USER@$UBUNTU_HOST:~/setup-ubuntu-server-v2026-01-30.sh"
    ssh "$UBUNTU_USER@$UBUNTU_HOST" "chmod +x ~/setup-ubuntu-server-v2026-01-30.sh && ~/setup-ubuntu-server-v2026-01-30.sh"
    echo -e "${YELLOW}Setup abgeschlossen. Bitte neu einloggen oder 'newgrp docker' auf Ubuntu ausführen.${NC}"
    read -p "Wurde 'newgrp docker' auf Ubuntu ausgeführt? (y/n): " DOCKER_READY
    if [ "$DOCKER_READY" != "y" ]; then
        echo -e "${YELLOW}Bitte auf Ubuntu 'newgrp docker' ausführen und Deployment erneut starten.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} Docker ist installiert"
fi

# Create remote directory structure
echo -e "\n${YELLOW}[3/6]${NC} Remote-Verzeichnisstruktur erstellen..."
ssh "$UBUNTU_USER@$UBUNTU_HOST" "mkdir -p $REMOTE_DIR/backend/{parse-server/{cloud,certs,logs},mongodb/init,postgres/init,nginx/{ssl,logs},market-data,notification-service/certs,analytics-service}"

# Copy backend files
echo -e "\n${YELLOW}[4/6]${NC} Backend-Dateien kopieren..."
rsync -avz --progress \
    --exclude='node_modules' \
    --exclude='.env' \
    --exclude='*.log' \
    --exclude='.git' \
    "$BACKEND_DIR/" "$UBUNTU_USER@$UBUNTU_HOST:$REMOTE_DIR/backend/"

# Copy docker-compose files
echo -e "\n${YELLOW}[5/6]${NC} Docker Compose Dateien kopieren..."
scp "$PROJECT_ROOT/docker-compose.yml" "$UBUNTU_USER@$UBUNTU_HOST:$REMOTE_DIR/docker-compose.yml"
scp "$PROJECT_ROOT/docker-compose.production.yml" "$UBUNTU_USER@$UBUNTU_HOST:$REMOTE_DIR/docker-compose.production.yml"

# Get Ubuntu IP for configuration
echo -e "\n${YELLOW}[6/6]${NC} Konfiguration anpassen..."
UBUNTU_IP=$(ssh "$UBUNTU_USER@$UBUNTU_HOST" "hostname -I | awk '{print \$1}'")
echo -e "${GREEN}✓${NC} Ubuntu IP: $UBUNTU_IP"

# Create production .env file
echo -e "\n${YELLOW}Erstelle Produktions-Umgebungsvariablen...${NC}"
UBUNTU_HOSTNAME=$(ssh "$UBUNTU_USER@$UBUNTU_HOST" "hostname")
ssh "$UBUNTU_USER@$UBUNTU_HOST" "cd $REMOTE_DIR/backend && \
    if [ ! -f .env ]; then \
        cp env.production.example .env && \
        sed -i \"s|YOUR-UBUNTU-IP|$UBUNTU_IP|g\" .env && \
        sed -i \"s|YOUR-UBUNTU-HOSTNAME|$UBUNTU_HOSTNAME|g\" .env && \
        echo \"# Auto-configured on \$(date)\" >> .env; \
    else \
        echo '.env existiert bereits - bitte manuell prüfen'; \
    fi"

# Update docker-compose.yml with production settings
echo -e "\n${YELLOW}Docker Compose für Produktion anpassen...${NC}"
ssh "$UBUNTU_USER@$UBUNTU_HOST" "cd $REMOTE_DIR && \
    sed -i \"s|http://localhost:1337/parse|http://$UBUNTU_IP:1338/parse|g\" docker-compose.yml && \
    sed -i \"s|ws://localhost:1337/parse|ws://$UBUNTU_IP:1338/parse|g\" docker-compose.yml"

# Copy production env example
scp "$PROJECT_ROOT/backend/env.production.example" "$UBUNTU_USER@$UBUNTU_HOST:$REMOTE_DIR/backend/env.production.example"

# Summary
echo -e "\n${GREEN}=========================================="
echo "Deployment abgeschlossen!"
echo "==========================================${NC}"
echo ""
echo "Server Details:"
echo "  IP: $UBUNTU_IP"
echo "  User: $UBUNTU_USER"
echo "  Verzeichnis: $REMOTE_DIR"
echo ""
echo "Nächste Schritte auf Ubuntu:"
echo "  1. Umgebungsvariablen anpassen:"
echo "     nano $REMOTE_DIR/backend/.env"
echo ""
echo "  2. Passwörter und Secrets ändern!"
echo ""
echo "  3. Server starten:"
echo "     cd $REMOTE_DIR"
echo "     docker compose -f docker-compose.production.yml up -d"
echo ""
echo "  4. Logs prüfen:"
echo "     docker compose logs -f"
echo ""
echo "  5. Services testen:"
echo "     curl http://$UBUNTU_IP/health"
echo ""
echo -e "${YELLOW}Wichtig:${NC} Bitte alle Passwörter in .env ändern!"
