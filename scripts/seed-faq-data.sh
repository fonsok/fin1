#!/bin/bash
# FIN1 FAQ-Daten seeden auf dem Backend-Server
# Ruft die Parse-Cloud-Funktion seedFAQData oder forceReseedFAQData auf.
#
# Usage:
#   ./seed-faq-data.sh                    # Interaktiv: Host/User eingeben
#   ./seed-faq-data.sh 192.168.178.24 io  # Nur seeden (FAQs hinzufügen, wenn leer)
#   ./seed-faq-data.sh 192.168.178.24 io --force  # Alte FAQs löschen und neu seeden (Investor/Trader-rollen)
#
# Voraussetzung: Parse Server läuft auf dem Zielrechner (z. B. docker compose up).
# Master-Key wird aus ~/fin1-server/backend/.env gelesen (PARSE_SERVER_MASTER_KEY).

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_DIR="~/fin1-server"
PARSE_URL="http://127.0.0.1:1338/parse"
APP_ID="fin1-app-id"

# Host/User aus Argumenten oder interaktiv
if [ -z "$1" ] || [ "$1" = "--force" ]; then
    echo -e "${YELLOW}FIN1 FAQ-Daten seeden${NC}"
    echo ""
    echo "Beispiel: $0 192.168.178.24 io [--force]"
    echo "  --force = bestehende FAQ-Daten löschen und neu seeden (role-aware)"
    echo ""
    read -p "Server (IP/Hostname): " UBUNTU_HOST
    read -p "User (z.B. io): " UBUNTU_USER
    FORCE_RESEED="${1:-}"
    if [ -z "$FORCE_RESEED" ]; then
        read -p "Force reseed? Bestehende FAQs löschen und neu anlegen? (j/n): " F
        [ "$F" = "j" ] || [ "$F" = "J" ] || [ "$F" = "y" ] || [ "$F" = "Y" ] && FORCE_RESEED="--force"
    fi
else
    UBUNTU_HOST="$1"
    UBUNTU_USER="${2:-io}"
    FORCE_RESEED="${3:-}"
fi

if [ -z "$UBUNTU_HOST" ]; then
    echo -e "${RED}Server fehlt.${NC}"
    exit 1
fi

FUNC="seedFAQData"
if [ "$FORCE_RESEED" = "--force" ]; then
    FUNC="forceReseedFAQData"
fi

echo -e "\n${BLUE}=========================================="
echo "FAQ-Daten seeden"
echo "==========================================${NC}"
echo "Server: $UBUNTU_USER@$UBUNTU_HOST"
echo "Funktion: $FUNC"
echo ""

# Auf dem Server: Master-Key aus .env lesen und Cloud-Funktion aufrufen
RESULT=$(ssh "$UBUNTU_USER@$UBUNTU_HOST" "cd $REMOTE_DIR && \
    if [ ! -f backend/.env ]; then echo '{\"error\":\".env nicht gefunden unter $REMOTE_DIR/backend/.env\"}'; exit 0; fi; \
    MK=\$(grep '^PARSE_SERVER_MASTER_KEY=' backend/.env 2>/dev/null | cut -d= -f2- | tr -d '\r\n'); \
    if [ -z \"\$MK\" ]; then echo '{\"error\":\"PARSE_SERVER_MASTER_KEY nicht in .env gefunden\"}'; exit 0; fi; \
    curl -s -X POST $PARSE_URL/functions/$FUNC \
        -H 'X-Parse-Application-Id: $APP_ID' \
        -H \"X-Parse-Master-Key: \$MK\" \
        -H 'Content-Type: application/json' \
        -d '{}'")

# Fehler von Parse (z.B. {"code":600}) oder Erfolg mit result
if echo "$RESULT" | grep -q '"code":'; then
    echo -e "${RED}Parse-Fehler:${NC}"
    echo "$RESULT" | head -5
    echo ""
    echo -e "${YELLOW}Tipp:${NC} Auf dem Server Logs prüfen:"
    echo "  ssh $UBUNTU_USER@$UBUNTU_HOST \"cd $REMOTE_DIR && docker compose -f docker-compose.production.yml logs --tail=80 parse-server\""
    exit 1
fi

if echo "$RESULT" | grep -q '"error":'; then
    echo -e "${RED}$RESULT${NC}"
    exit 1
fi

echo -e "${GREEN}Ergebnis:${NC}"
echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
echo ""
echo -e "${GREEN}Fertig.${NC}"
