#!/bin/bash

# Script: Erstellt ComplianceEvent-Klasse automatisch
# Versucht verschiedene Methoden, bis eine funktioniert

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
echo "ComplianceEvent-Klasse automatisch erstellen"
echo "=========================================="
echo ""

# Methode 1: Warte auf Server und erstelle direkt
echo -e "${BLUE}[Methode 1]${NC} Warte auf Parse Server und erstelle Klasse direkt..."
for i in {1..30}; do
    # Prüfe ob Server bereit ist
    HEALTH=$(curl -s http://$UBUNTU_IP:1338/parse/health 2>&1 || echo "failed")

    if echo "$HEALTH" | grep -q '"status"[[:space:]]*:[[:space:]]*"ok"'; then
        # Versuche Klasse zu erstellen
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
            echo -e "${GREEN}✓${NC} ComplianceEvent-Klasse erfolgreich erstellt!"
            echo "   Object ID: $OBJECT_ID"

            # Lösche Test-Objekt
            echo ""
            echo -e "${BLUE}[Cleanup]${NC} Lösche Test-Objekt..."
            DELETE_RESPONSE=$(curl -s -X DELETE "http://$UBUNTU_IP:1338/parse/classes/ComplianceEvent/$OBJECT_ID" \
              -H "X-Parse-Application-Id: $APP_ID" \
              -H "X-Parse-Master-Key: $MASTER_KEY" 2>&1)

            if echo "$DELETE_RESPONSE" | grep -q "{}"; then
                echo -e "${GREEN}✓${NC} Test-Objekt gelöscht"
            fi

            echo ""
            echo -e "${GREEN}✅ Erfolg!${NC} ComplianceEvent-Klasse ist jetzt verfügbar!"
            exit 0
        elif echo "$RESPONSE" | grep -q "Invalid server state"; then
            echo "   Server noch nicht bereit (Versuch $i/30)..."
            sleep 3
        else
            echo "   Antwort: $RESPONSE"
            break
        fi
    else
        echo "   Warte auf Parse Server... ($i/30)"
        sleep 2
    fi
done

# Methode 2: Erstelle Collection direkt in MongoDB
echo ""
echo -e "${BLUE}[Methode 2]${NC} Erstelle Collection direkt in MongoDB..."
MONGODB_RESULT=$(ssh io@$UBUNTU_IP "cd ~/fin1-server && docker compose -f docker-compose.production.yml exec -T mongodb mongosh --quiet --eval 'use fin1; db.createCollection(\"ComplianceEvent\"); print(\"Collection created\")' 2>&1" || echo "failed")

if echo "$MONGODB_RESULT" | grep -q "Collection created\|already exists"; then
    echo -e "${GREEN}✓${NC} Collection in MongoDB erstellt"
    echo ""
    echo -e "${YELLOW}⚠${NC} Collection erstellt, aber Parse Server Schema muss noch initialisiert werden."
    echo "   Die Klasse wird automatisch erstellt, wenn die App das nächste Mal ein Compliance Event speichert."
    echo ""
    echo "   Oder: Öffne Parse Dashboard und erstelle die Klasse manuell:"
    echo "   http://$UBUNTU_IP:1338/dashboard"
    exit 0
else
    echo -e "${RED}✗${NC} MongoDB-Methode fehlgeschlagen"
fi

# Methode 3: Finale Anweisungen
echo ""
echo -e "${YELLOW}⚠${NC} Automatische Erstellung fehlgeschlagen"
echo ""
echo "Bitte erstelle die Klasse manuell über das Parse Dashboard:"
echo ""
echo "1. Öffne: http://$UBUNTU_IP:1338/dashboard"
echo "2. Login: admin / CHANGE-THIS-ADMIN-PASSWORD"
echo "3. Schema → Create Class → ComplianceEvent"
echo "4. Felder hinzufügen (siehe DASHBOARD_ANLEITUNG.md)"
echo ""
echo "Oder warte, bis die App die Klasse automatisch erstellt"
echo "(beim nächsten Compliance Event Save)"

exit 1
