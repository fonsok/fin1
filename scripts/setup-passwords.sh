#!/bin/bash
# Generiert sichere Passwörter und aktualisiert .env Datei
# Auf Ubuntu ausführen: ~/fin1-server/backend/

set -e

echo "=========================================="
echo "FIN1 Passwort-Generierung"
echo "=========================================="
echo ""

ENV_FILE="${1:-./backend/.env}"

if [ ! -f "$ENV_FILE" ]; then
    echo "Fehler: .env Datei nicht gefunden: $ENV_FILE"
    echo "Verwendung: ./setup-passwords-v2026-01-30.sh [pfad-zur-.env]"
    exit 1
fi

echo "Generiere sichere Passwörter..."
echo ""

# Generiere Passwörter
PARSE_MASTER_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
MONGO_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Backup erstellen
cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✓ Backup erstellt: ${ENV_FILE}.backup.*"

# Passwörter in .env ersetzen
echo ""
echo "Aktualisiere .env Datei..."

# Parse Server
sed -i "s|PARSE_SERVER_MASTER_KEY=.*|PARSE_SERVER_MASTER_KEY=$PARSE_MASTER_KEY|g" "$ENV_FILE"
sed -i "s|MONGO_INITDB_ROOT_PASSWORD=.*|MONGO_INITDB_ROOT_PASSWORD=$MONGO_PASSWORD|g" "$ENV_FILE"
sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|g" "$ENV_FILE"
sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$REDIS_PASSWORD|g" "$ENV_FILE"
sed -i "s|JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|g" "$ENV_FILE"
sed -i "s|ENCRYPTION_KEY=.*|ENCRYPTION_KEY=$ENCRYPTION_KEY|g" "$ENV_FILE"

# MongoDB URI aktualisieren
sed -i "s|MONGO_INITDB_ROOT_PASSWORD|$MONGO_PASSWORD|g" "$ENV_FILE"
sed -i "s|mongodb://admin:.*@mongodb|mongodb://admin:$MONGO_PASSWORD@mongodb|g" "$ENV_FILE"

# PostgreSQL URL aktualisieren
sed -i "s|POSTGRES_PASSWORD|$POSTGRES_PASSWORD|g" "$ENV_FILE"
sed -i "s|postgresql://fin1_user:.*@postgres|postgresql://fin1_user:$POSTGRES_PASSWORD@postgres|g" "$ENV_FILE"

# Redis URL aktualisieren
sed -i "s|redis://:.*@redis|redis://:$REDIS_PASSWORD@redis|g" "$ENV_FILE"

echo "✓ Passwörter aktualisiert!"
echo ""
echo "=========================================="
echo "Fertig!"
echo "=========================================="
echo ""
echo "Die .env Datei wurde mit sicheren Passwörtern aktualisiert."
echo "Backup wurde erstellt: ${ENV_FILE}.backup.*"
echo ""
echo "Nächster Schritt: Server starten"
echo "  cd ~/fin1-server"
echo "  docker compose -f docker-compose.production.yml up -d"
echo ""
