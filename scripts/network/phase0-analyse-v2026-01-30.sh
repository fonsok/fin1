#!/bin/bash

# Phase 0: Analyse & Vorbereitung
# Dokumentiert die aktuelle Situation auf Ubuntu-Server und Mac

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_FILE="$PROJECT_ROOT/PHASE0_ANALYSE_ERGEBNISSE.md"

UBUNTU_IP="${1:-192.168.178.24}"
UBUNTU_USER="${2:-io}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Phase 0: Analyse & Vorbereitung"
echo "=========================================="
echo ""
echo "Ubuntu Server IP: $UBUNTU_IP"
echo "Ubuntu User: $UBUNTU_USER"
echo ""

# Create output file
cat > "$OUTPUT_FILE" << EOF
# Phase 0: Analyse & Vorbereitung - Ergebnisse

**Datum:** $(date)
**Ubuntu Server IP:** $UBUNTU_IP
**Ubuntu User:** $UBUNTU_USER

---

## Schritt 0.1: Aktuelle Situation dokumentieren

### Ubuntu-Server Informationen

EOF

echo -e "${BLUE}[1/7]${NC} Teste Verbindung zum Ubuntu-Server..."
if ping -c 3 -W 2 "$UBUNTU_IP" &> /dev/null; then
    echo -e "${GREEN}✓${NC} Ubuntu-Server ist erreichbar"
    echo "" >> "$OUTPUT_FILE"
    echo "✅ Ubuntu-Server ist erreichbar (Ping erfolgreich)" >> "$OUTPUT_FILE"
else
    echo -e "${RED}✗${NC} Ubuntu-Server nicht erreichbar"
    echo "" >> "$OUTPUT_FILE"
    echo "❌ Ubuntu-Server nicht erreichbar (Ping fehlgeschlagen)" >> "$OUTPUT_FILE"
    exit 1
fi

echo -e "${BLUE}[2/7]${NC} Sammle Ubuntu-Server-Informationen..."
echo "" >> "$OUTPUT_FILE"
echo "### Server-Informationen" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"

# Get server info via SSH
if ssh -o ConnectTimeout=5 -o BatchMode=yes "$UBUNTU_USER@$UBUNTU_IP" exit 2>/dev/null; then
    echo "SSH-Verbindung erfolgreich" >> "$OUTPUT_FILE"
    
    # Get server IP
    SERVER_IP=$(ssh "$UBUNTU_USER@$UBUNTU_IP" "hostname -I | awk '{print \$1}'" 2>/dev/null || echo "unbekannt")
    echo "Server IP: $SERVER_IP" >> "$OUTPUT_FILE"
    
    # Get hostname
    HOSTNAME=$(ssh "$UBUNTU_USER@$UBUNTU_IP" "hostname" 2>/dev/null || echo "unbekannt")
    echo "Hostname: $HOSTNAME" >> "$OUTPUT_FILE"
    
    # Get network interface info
    echo "" >> "$OUTPUT_FILE"
    echo "### Netzwerk-Interface" >> "$OUTPUT_FILE"
    ssh "$UBUNTU_USER@$UBUNTU_IP" "ip addr show | grep -E 'inet |^[0-9]+:'" >> "$OUTPUT_FILE" 2>/dev/null || echo "Konnte Netzwerk-Info nicht abrufen" >> "$OUTPUT_FILE"
    
    echo -e "${GREEN}✓${NC} Server-Informationen gesammelt"
else
    echo "SSH-Verbindung nicht möglich (möglicherweise kein SSH-Key konfiguriert)" >> "$OUTPUT_FILE"
    echo -e "${YELLOW}⚠${NC} SSH-Verbindung nicht möglich - manuelle Eingabe erforderlich"
fi

echo "\`\`\`" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo -e "${BLUE}[3/7]${NC} Prüfe Firewall-Status..."
echo "### Firewall (UFW)" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
if ssh -o ConnectTimeout=5 "$UBUNTU_USER@$UBUNTU_IP" "sudo ufw status verbose" >> "$OUTPUT_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Firewall-Status geprüft"
else
    echo "Firewall-Status konnte nicht abgerufen werden" >> "$OUTPUT_FILE"
fi
echo "\`\`\`" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo -e "${BLUE}[4/7]${NC} Prüfe Docker-Netzwerk..."
echo "### Docker-Netzwerk" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
if ssh -o ConnectTimeout=5 "$UBUNTU_USER@$UBUNTU_IP" "docker network ls" >> "$OUTPUT_FILE" 2>/dev/null; then
    echo "" >> "$OUTPUT_FILE"
    ssh "$UBUNTU_USER@$UBUNTU_IP" "docker network inspect fin1-network 2>/dev/null | grep -A 5 Subnet || echo 'Network fin1-network not found'" >> "$OUTPUT_FILE" 2>/dev/null
    echo -e "${GREEN}✓${NC} Docker-Netzwerk geprüft"
else
    echo "Docker nicht verfügbar oder nicht installiert" >> "$OUTPUT_FILE"
fi
echo "\`\`\`" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo -e "${BLUE}[5/7]${NC} Prüfe Service-Status..."
echo "### Service-Status" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
if ssh -o ConnectTimeout=5 "$UBUNTU_USER@$UBUNTU_IP" "cd ~/fin1-server && docker compose -f docker-compose.production.yml ps" >> "$OUTPUT_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Service-Status geprüft"
else
    echo "Services konnten nicht abgerufen werden" >> "$OUTPUT_FILE"
fi
echo "\`\`\`" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo -e "${BLUE}[6/7]${NC} Analysiere problematische Services..."
echo "### Problematische Services" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check for restarting services
RESTARTING_SERVICES=$(ssh "$UBUNTU_USER@$UBUNTU_IP" "cd ~/fin1-server && docker compose -f docker-compose.production.yml ps 2>/dev/null | grep restarting | awk '{print \$1}'" 2>/dev/null || echo "")

if [ -n "$RESTARTING_SERVICES" ]; then
    echo "**Services im 'restarting' Status:**" >> "$OUTPUT_FILE"
    for service in $RESTARTING_SERVICES; do
        echo "- $service" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "#### $service Logs (letzte 30 Zeilen)" >> "$OUTPUT_FILE"
        echo "\`\`\`" >> "$OUTPUT_FILE"
        ssh "$UBUNTU_USER@$UBUNTU_IP" "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs --tail=30 $service" >> "$OUTPUT_FILE" 2>/dev/null || echo "Logs konnten nicht abgerufen werden" >> "$OUTPUT_FILE"
        echo "\`\`\`" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    done
    echo -e "${YELLOW}⚠${NC} Problematische Services gefunden: $RESTARTING_SERVICES"
else
    echo "✅ Keine Services im 'restarting' Status" >> "$OUTPUT_FILE"
    echo -e "${GREEN}✓${NC} Keine problematischen Services gefunden"
fi

echo -e "${BLUE}[7/7]${NC} Teste Port-Verfügbarkeit vom Mac..."
echo "" >> "$OUTPUT_FILE"
echo "## Schritt 0.2: Netzwerk-Verbindungstest (vom Mac)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "### Port-Verfügbarkeit" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"

PORTS=(80 1337 8080 8081 8082 9000 9001)
for port in "${PORTS[@]}"; do
    if nc -zv -G 2 "$UBUNTU_IP" "$port" >> "$OUTPUT_FILE" 2>&1; then
        echo -e "${GREEN}✓${NC} Port $port erreichbar"
    else
        echo -e "${RED}✗${NC} Port $port nicht erreichbar"
    fi
done

echo "\`\`\`" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Mac information
echo "### Mac-Informationen" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
echo "Mac IP: $(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 'unbekannt')" >> "$OUTPUT_FILE"
echo "Netzwerk: 192.168.178.0/24" >> "$OUTPUT_FILE"
echo "Fritzbox IP: 192.168.178.1" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## Zusammenfassung" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "### Identifizierte Probleme:" >> "$OUTPUT_FILE"
if [ -n "$RESTARTING_SERVICES" ]; then
    echo "- Services im 'restarting' Status: $RESTARTING_SERVICES" >> "$OUTPUT_FILE"
else
    echo "- Keine kritischen Probleme identifiziert" >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "### Nächste Schritte:" >> "$OUTPUT_FILE"
echo "1. Phase 1: Service-Stabilität herstellen" >> "$OUTPUT_FILE"
echo "2. Phase 2: Netzwerk-Konfiguration optimieren" >> "$OUTPUT_FILE"
echo "3. Phase 3: Backend-Konfiguration anpassen" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "=========================================="
echo -e "${GREEN}Phase 0 Analyse abgeschlossen!${NC}"
echo "=========================================="
echo ""
echo "Ergebnisse gespeichert in: $OUTPUT_FILE"
echo ""
