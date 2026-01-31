#!/bin/bash

# Script: Kopiert Parse Server Code auf Ubuntu Server
# Verwendet: scp zum Kopieren der index.js Datei

set -e

UBUNTU_IP="${1:-192.168.178.24}"
UBUNTU_USER="${2:-io}"
UBUNTU_PATH="${3:-~/fin1-server}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Parse Server Code auf Ubuntu kopieren"
echo "=========================================="
echo ""

# Prüfe ob Datei existiert
if [ ! -f "backend/parse-server/index.js" ]; then
    echo -e "${RED}✗${NC} Datei backend/parse-server/index.js nicht gefunden!"
    exit 1
fi

echo -e "${BLUE}[1/3]${NC} Kopiere Parse Server index.js..."
scp backend/parse-server/index.js "$UBUNTU_USER@$UBUNTU_IP:$UBUNTU_PATH/backend/parse-server/index.js"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Datei erfolgreich kopiert"
else
    echo -e "${RED}✗${NC} Fehler beim Kopieren"
    exit 1
fi

echo ""
echo -e "${BLUE}[2/3]${NC} Prüfe ob Datei auf Server existiert..."
ssh "$UBUNTU_USER@$UBUNTU_IP" "test -f $UBUNTU_PATH/backend/parse-server/index.js && echo 'Datei gefunden' || echo 'Datei nicht gefunden'"

echo ""
echo -e "${BLUE}[3/3]${NC} Parse Server neu bauen und starten..."
read -p "Parse Server jetzt neu bauen? (j/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Jj]$ ]]; then
    echo "Baue Parse Server neu..."
    ssh "$UBUNTU_USER@$UBUNTU_IP" "cd $UBUNTU_PATH && docker compose -f docker-compose.production.yml up -d --build parse-server"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Parse Server erfolgreich neu gebaut"
        echo ""
        echo "Prüfe Logs:"
        echo "  ssh $UBUNTU_USER@$UBUNTU_IP 'cd $UBUNTU_PATH && docker compose -f docker-compose.production.yml logs -f parse-server'"
    else
        echo -e "${RED}✗${NC} Fehler beim Neubauen"
        exit 1
    fi
else
    echo "Überspringe Neubau. Führe manuell aus:"
    echo "  ssh $UBUNTU_USER@$UBUNTU_IP 'cd $UBUNTU_PATH && docker compose -f docker-compose.production.yml up -d --build parse-server'"
fi
echo ""
