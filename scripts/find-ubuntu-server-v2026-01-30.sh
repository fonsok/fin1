#!/bin/bash
# Findet Ubuntu-Server im lokalen Netzwerk
# Scans das lokale Netzwerk nach Ubuntu 24.04 Systemen
#
# Voraussetzungen:
# - Fritzbox: Feste IP für Ubuntu-Server vergeben
# - Fritzbox: WLAN-Geräte anzeigen aktivieren
# - Ubuntu: SSH-Server aktiviert

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "Ubuntu-Server im Netzwerk suchen"
echo "==========================================${NC}"
echo ""
echo -e "${YELLOW}Hinweis:${NC} Für bessere Ergebnisse:"
echo "  1. Fritzbox: Feste IP für Ubuntu-Server vergeben"
echo "  2. Siehe: scripts/FRITZBOX_SETUP.md für Details"
echo ""

# Get local network interface and IP
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "192.168.178.1")
NETWORK=$(echo $LOCAL_IP | cut -d'.' -f1-3)

# Try to detect Fritzbox network (common: 192.168.178.x)
if [[ "$NETWORK" == "192.168.178" ]]; then
    FRITZBOX_IP="192.168.178.1"
    echo -e "${GREEN}✓${NC} Fritzbox-Netzwerk erkannt: $NETWORK.0/24"
    echo -e "${GREEN}✓${NC} Fritzbox IP: $FRITZBOX_IP"
else
    FRITZBOX_IP="${NETWORK}.1"
    echo -e "${YELLOW}Netzwerk: $NETWORK.0/24${NC}"
    echo -e "${YELLOW}Router IP (angenommen): $FRITZBOX_IP${NC}"
fi

echo -e "${YELLOW}Lokale IP: $LOCAL_IP${NC}"
echo ""
echo "Suche nach Ubuntu-Servern..."
echo ""

# Try to get devices from ARP table first (faster)
echo -e "${YELLOW}[1/3]${NC} Prüfe ARP-Tabelle (schnell)..."
ARP_HOSTS=$(arp -a | grep -E "$NETWORK\.[0-9]+" | awk '{print $2}' | tr -d '()' | sort -u || echo "")

if [ ! -z "$ARP_HOSTS" ]; then
    echo -e "${GREEN}✓${NC} Gefundene Geräte im ARP-Cache:"
    for HOST in $ARP_HOSTS; do
        # Try to identify Ubuntu by hostname or SSH
        HOSTNAME=$(host "$HOST" 2>/dev/null | sed -n 's/.*pointer \(.*\)/\1/p' || echo "unbekannt")
        if echo "$HOSTNAME" | grep -qi "ubuntu\|linux"; then
            echo -e "  ${GREEN}→${NC} $HOST ($HOSTNAME) - möglicher Ubuntu-Server"
        fi
    done
    echo ""
fi

# Check if nmap is installed
if ! command -v nmap &> /dev/null; then
    echo -e "${YELLOW}[2/3]${NC} nmap nicht gefunden. Installiere...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install nmap
        else
            echo -e "${RED}✗${NC} nmap nicht installiert"
            echo -e "${YELLOW}Installiere mit: brew install nmap${NC}"
            echo ""
            echo -e "${YELLOW}Alternative: Manuell IP eingeben${NC}"
            read -p "Ubuntu Server IP: " MANUAL_IP
            if [ ! -z "$MANUAL_IP" ]; then
                echo ""
                echo -e "${GREEN}Gefundener Server:${NC}"
                echo "  IP: $MANUAL_IP"
                echo ""
                echo "Teste Verbindung..."
                if ping -c 1 -W 2 "$MANUAL_IP" &> /dev/null; then
                    echo -e "${GREEN}✓${NC} Server ist erreichbar"
                    echo ""
                    echo "Verwende diesen Server für Deployment:"
                    echo "  ./deploy-to-ubuntu-v2026-01-30.sh $MANUAL_IP"
                else
                    echo -e "${RED}✗${NC} Server nicht erreichbar"
                fi
            fi
            exit 0
        fi
    else
        echo -e "${YELLOW}Bitte nmap installieren${NC}"
        exit 1
    fi
fi

# Scan network for SSH servers
echo -e "${YELLOW}[2/3]${NC} Scanne Netzwerk nach SSH-Servern (Port 22)..."
echo -e "${YELLOW}Dies kann einige Sekunden dauern...${NC}"
SSH_HOSTS=$(nmap -p 22 --open "$NETWORK.0/24" 2>/dev/null | grep -E "Nmap scan report" | awk '{print $5}' | grep -E "$NETWORK\.[0-9]+" || echo "")

# Try to identify Ubuntu systems
echo -e "${YELLOW}[3/3]${NC} Identifiziere Ubuntu-Systeme..."
UBUNTU_HOSTS=""
for HOST in $SSH_HOSTS; do
    # Try SSH banner detection
    SSH_BANNER=$(timeout 2 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no "$HOST" 2>&1 | grep -i "ubuntu\|linux" || echo "")
    if [ ! -z "$SSH_BANNER" ] || echo "$HOST" | grep -qE "192\.168\.(178|1)\.[0-9]+"; then
        # Try to get more info
        OS_INFO=$(timeout 2 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no "$HOST" "uname -a 2>/dev/null" 2>/dev/null || echo "")
        if echo "$OS_INFO" | grep -qi "ubuntu\|linux"; then
            UBUNTU_HOSTS="$UBUNTU_HOSTS $HOST"
        fi
    fi
done

if [ -z "$SSH_HOSTS" ] && [ -z "$UBUNTU_HOSTS" ]; then
    echo -e "${RED}✗${NC} Keine SSH-Server gefunden."
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  1. Prüfe Fritzbox-Konfiguration: scripts/FRITZBOX_SETUP.md"
    echo "  2. Prüfe ob Ubuntu-Server im WLAN verbunden ist"
    echo "  3. Prüfe ob SSH auf Ubuntu aktiviert ist: sudo systemctl status ssh"
    echo ""
    echo -e "${YELLOW}Alternative: Manuell IP eingeben${NC}"
    read -p "Ubuntu Server IP: " MANUAL_IP
    if [ ! -z "$MANUAL_IP" ]; then
        echo ""
        echo -e "${GREEN}Gefundener Server:${NC}"
        echo "  IP: $MANUAL_IP"
        echo ""
        echo "Teste Verbindung..."
        if ping -c 1 -W 2 "$MANUAL_IP" &> /dev/null; then
            echo -e "${GREEN}✓${NC} Server ist erreichbar"
            echo ""
            # Test SSH
            if timeout 2 ssh -o ConnectTimeout=2 -o BatchMode=yes "$MANUAL_IP" exit 2>/dev/null; then
                echo -e "${GREEN}✓${NC} SSH-Verbindung erfolgreich"
                echo ""
                echo "Verwende diesen Server für Deployment:"
                echo "  ./deploy-to-ubuntu-v2026-01-30.sh $MANUAL_IP"
            else
                echo -e "${YELLOW}⚠${NC} SSH-Verbindung nicht möglich"
                echo "  Bitte SSH auf Ubuntu aktivieren: sudo systemctl enable ssh"
            fi
        else
            echo -e "${RED}✗${NC} Server nicht erreichbar"
            echo "  Prüfe Netzwerk-Verbindung und Fritzbox-Einstellungen"
        fi
    fi
else
    echo ""
    if [ ! -z "$UBUNTU_HOSTS" ]; then
        echo -e "${GREEN}✓${NC} Gefundene Ubuntu-Server:"
        for HOST in $UBUNTU_HOSTS; do
            echo -e "  ${GREEN}→${NC} $HOST (Ubuntu erkannt)"
        done
        echo ""
        FIRST_HOST=$(echo $UBUNTU_HOSTS | awk '{print $1}')
    elif [ ! -z "$SSH_HOSTS" ]; then
        echo -e "${YELLOW}⚠${NC} SSH-Server gefunden (Ubuntu nicht eindeutig identifiziert):"
        for HOST in $SSH_HOSTS; do
            echo "  - $HOST"
        done
        echo ""
        FIRST_HOST=$(echo $SSH_HOSTS | awk '{print $1}')
    fi

    echo "Verwende für Deployment:"
    echo "  ./deploy-to-ubuntu-v2026-01-30.sh $FIRST_HOST"
    echo ""
    echo -e "${YELLOW}Tipp:${NC} Für bessere Erkennung:"
    echo "  - Fritzbox: Feste IP für Ubuntu vergeben"
    echo "  - Ubuntu: Hostname setzen (z.B. 'fin1-server')"
    echo "  - Siehe: scripts/FRITZBOX_SETUP.md"
fi
