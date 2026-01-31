#!/bin/bash

# Phase 2: Netzwerk-Konfiguration
# Konfiguriert Firewall und Netzwerk für lokales Netzwerk

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
echo "Phase 2: Netzwerk-Konfiguration"
echo "=========================================="
echo ""

echo -e "${BLUE}[1/4]${NC} Prüfe Firewall-Status..."
UFW_STATUS=$(ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw status 2>&1" | head -1)
echo "UFW Status: $UFW_STATUS"

if echo "$UFW_STATUS" | grep -q "inactive"; then
    echo -e "${YELLOW}UFW ist inaktiv${NC}"
    echo -e "${BLUE}[2/4]${NC} Konfiguriere Firewall für lokales Netzwerk..."
    
    # Firewall-Regeln für lokales Netzwerk hinzufügen
    ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 22 comment 'SSH'" 2>&1
    ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 80 comment 'Nginx HTTP'" 2>&1
    ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 1337 comment 'Parse Server'" 2>&1
    ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 8080 comment 'Market Data'" 2>&1
    ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 8081 comment 'Notification Service'" 2>&1
    ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 8082 comment 'Analytics Service'" 2>&1
    ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 9000 comment 'MinIO'" 2>&1
    ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 9001 comment 'MinIO Console'" 2>&1
    
    echo -e "${BLUE}[3/4]${NC} Aktiviere Firewall..."
    ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw --force enable" 2>&1
    
    echo -e "${GREEN}✓${NC} Firewall konfiguriert"
else
    echo -e "${YELLOW}UFW ist bereits aktiv${NC}"
    echo -e "${BLUE}[2/4]${NC} Prüfe bestehende Regeln..."
    
    # Prüfe ob Regeln bereits existieren
    EXISTING_RULES=$(ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw status numbered 2>&1" | grep -c "192.168.178" || echo "0")
    
    if [ "$EXISTING_RULES" -eq "0" ]; then
        echo "Füge Firewall-Regeln hinzu..."
        ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 22 comment 'SSH'" 2>&1
        ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 80 comment 'Nginx HTTP'" 2>&1
        ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 1337 comment 'Parse Server'" 2>&1
        ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 8080 comment 'Market Data'" 2>&1
        ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 8081 comment 'Notification Service'" 2>&1
        ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 8082 comment 'Analytics Service'" 2>&1
        ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 9000 comment 'MinIO'" 2>&1
        ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw allow from 192.168.178.0/24 to any port 9001 comment 'MinIO Console'" 2>&1
        echo -e "${GREEN}✓${NC} Firewall-Regeln hinzugefügt"
    else
        echo -e "${GREEN}✓${NC} Firewall-Regeln bereits vorhanden"
    fi
fi

echo -e "${BLUE}[4/4]${NC} Zeige Firewall-Status..."
ssh "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw status numbered 2>&1" | grep -E "Status|192.168.178|80|1337|8080" | head -10

echo ""
echo "=========================================="
echo -e "${GREEN}Phase 2: Netzwerk-Konfiguration abgeschlossen!${NC}"
echo "=========================================="
echo ""
