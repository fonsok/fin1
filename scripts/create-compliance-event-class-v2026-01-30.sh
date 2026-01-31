#!/bin/bash

# Script: Erstellt ComplianceEvent-Klasse im Parse Server
# Parse Server erstellt Klassen automatisch beim ersten Objekt-Save
# Dieses Script wartet, bis der Server bereit ist, und erstellt dann ein Test-Objekt

set -e

UBUNTU_IP="${1:-192.168.178.24}"
APP_ID="${2:-fin1-app-id}"
MASTER_KEY="${3:-LKs8B69ONq3rAL37FCScXDL07932gx0k}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "ComplianceEvent-Klasse erstellen"
echo "=========================================="
echo ""

echo -e "${BLUE}[1/3]${NC} Prüfe Parse Server Status..."
for i in {1..10}; do
    HEALTH=$(curl -s http://$UBUNTU_IP:1338/parse/health 2>&1 || echo "failed")
    if echo "$HEALTH" | grep -q '"status"[[:space:]]*:[[:space:]]*"ok"'; then
        echo -e "${GREEN}✓${NC} Parse Server ist bereit"
        break
    else
        echo "Warte auf Parse Server... ($i/10)"
        sleep 2
    fi
    if [ $i -eq 10 ]; then
        echo -e "${RED}✗${NC} Parse Server ist nicht bereit"
        exit 1
    fi
done

echo ""
echo -e "${BLUE}[2/3]${NC} Erstelle Test-Objekt in ComplianceEvent-Klasse..."
# Parse Server erstellt die Klasse automatisch beim ersten Objekt
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
RESPONSE=$(curl -s -X POST "http://$UBUNTU_IP:1338/parse/classes/ComplianceEvent" \
  -H "X-Parse-Application-Id: $APP_ID" \
  -H "X-Parse-Master-Key: $MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": \"system-init\",
    \"eventType\": \"systemInit\",
    \"description\": \"ComplianceEvent class initialization\",
    \"metadata\": {\"init\": \"true\"},
    \"timestamp\": \"$TIMESTAMP\",
    \"regulatoryFlags\": []
  }" 2>&1)

if echo "$RESPONSE" | grep -q "objectId"; then
    OBJECT_ID=$(echo "$RESPONSE" | grep -o '"objectId":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓${NC} ComplianceEvent-Klasse erstellt!"
    echo "   Object ID: $OBJECT_ID"

    echo ""
    echo -e "${BLUE}[3/3]${NC} Lösche Test-Objekt..."
    DELETE_RESPONSE=$(curl -s -X DELETE "http://$UBUNTU_IP:1338/parse/classes/ComplianceEvent/$OBJECT_ID" \
      -H "X-Parse-Application-Id: $APP_ID" \
      -H "X-Parse-Master-Key: $MASTER_KEY" 2>&1)

    if echo "$DELETE_RESPONSE" | grep -q "{}"; then
        echo -e "${GREEN}✓${NC} Test-Objekt gelöscht"
    else
        echo -e "${YELLOW}⚠${NC} Test-Objekt konnte nicht gelöscht werden (nicht kritisch)"
    fi
else
    echo -e "${YELLOW}⚠${NC} Antwort: $RESPONSE"
    echo ""
    echo "Parse Server erstellt Klassen automatisch beim ersten Objekt-Save."
    echo "Die Klasse wird erstellt, wenn die App das nächste Mal ein Compliance Event speichert."
    echo ""
    echo "Alternativ: Öffne Parse Dashboard:"
    echo "  http://$UBUNTU_IP:1338/dashboard"
    echo "  → Schema → Create Class → ComplianceEvent"
fi

echo ""
echo "=========================================="
echo "Fertig!"
echo "=========================================="
echo ""
echo "Die ComplianceEvent-Klasse sollte jetzt verfügbar sein."
echo "Teste in der App - die 500-Fehler sollten verschwinden."
