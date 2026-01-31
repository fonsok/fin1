#!/bin/bash
# FIN1 Server Setup Script for Ubuntu 24.04 LTS
# This script installs and configures all necessary components for FIN1 backend

set -e  # Exit on error

echo "=========================================="
echo "FIN1 Server Setup für Ubuntu 24.04 LTS"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then
   echo -e "${RED}Error: Bitte nicht als root ausführen. Verwende 'sudo' nur wenn nötig.${NC}"
   exit 1
fi

# Get Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
echo -e "${GREEN}✓${NC} Ubuntu Version: $UBUNTU_VERSION"

# Update system packages
echo -e "\n${YELLOW}[1/8]${NC} System-Pakete aktualisieren..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo -e "\n${YELLOW}[2/8]${NC} Basis-Pakete installieren..."
sudo apt install -y \
    curl \
    wget \
    git \
    vim \
    ufw \
    openssh-server \
    ca-certificates \
    gnupg \
    lsb-release \
    net-tools \
    htop \
    unattended-upgrades

# Install Docker
echo -e "\n${YELLOW}[3/8]${NC} Docker installieren..."
if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add current user to docker group
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✓${NC} Docker installiert. Bitte neu einloggen oder 'newgrp docker' ausführen."
else
    echo -e "${GREEN}✓${NC} Docker ist bereits installiert."
fi

# Install Docker Compose (standalone, falls nicht vorhanden)
echo -e "\n${YELLOW}[4/8]${NC} Docker Compose prüfen..."
if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Docker Compose Plugin wird installiert...${NC}"
    sudo apt install -y docker-compose-plugin
else
    echo -e "${GREEN}✓${NC} Docker Compose ist bereits installiert."
fi

# Configure firewall
echo -e "\n${YELLOW}[5/8]${NC} Firewall konfigurieren..."
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 1337/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 8081/tcp
sudo ufw allow 8082/tcp
echo -e "${GREEN}✓${NC} Firewall konfiguriert."

# Get network information
echo -e "\n${YELLOW}[6/8]${NC} Netzwerk-Informationen sammeln..."
HOST_IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)
echo -e "${GREEN}✓${NC} Server IP: $HOST_IP"
echo -e "${GREEN}✓${NC} Hostname: $HOSTNAME"

# Create FIN1 directory structure
echo -e "\n${YELLOW}[7/8]${NC} Verzeichnisstruktur erstellen..."
FIN1_DIR="$HOME/fin1-server"
mkdir -p "$FIN1_DIR"/{backend/{parse-server/{cloud,certs,logs},mongodb/init,postgres/init,nginx/{ssl,logs},market-data,notification-service/certs,analytics-service},scripts,logs,backups}
echo -e "${GREEN}✓${NC} Verzeichnisstruktur erstellt: $FIN1_DIR"

# Create systemd service for auto-start (optional)
echo -e "\n${YELLOW}[8/8]${NC} Systemd-Service erstellen..."
sudo tee /etc/systemd/system/fin1-server.service > /dev/null <<EOF
[Unit]
Description=FIN1 Backend Server
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$FIN1_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0
User=$USER
Group=$USER

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✓${NC} Systemd-Service erstellt (optional aktivieren mit: sudo systemctl enable fin1-server)"

# Summary
echo -e "\n${GREEN}=========================================="
echo "Setup abgeschlossen!"
echo "==========================================${NC}"
echo ""
echo "Nächste Schritte:"
echo "1. Neu einloggen oder 'newgrp docker' ausführen"
echo "2. FIN1 Backend-Dateien nach $FIN1_DIR kopieren"
echo "3. Umgebungsvariablen in $FIN1_DIR/backend/.env konfigurieren"
echo "4. Server starten mit: cd $FIN1_DIR && docker compose up -d"
echo ""
echo "Server IP: $HOST_IP"
echo "SSH-Zugriff: ssh $USER@$HOST_IP"
echo ""
echo -e "${YELLOW}Hinweis:${NC} Bitte die Dateien vom Mac-Rechner kopieren und .env konfigurieren!"
