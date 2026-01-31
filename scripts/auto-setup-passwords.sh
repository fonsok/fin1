#!/bin/bash
# Automatisches Setup der Passwörter für FIN1
# Auf Ubuntu ausführen: cd ~/fin1-server && bash auto-setup-passwords-v2026-01-30.sh

set -e

echo "=========================================="
echo "FIN1 Passwort-Setup (Automatisch)"
echo "=========================================="
echo ""

# Prüfe ob wir im richtigen Verzeichnis sind
if [ ! -f "backend/.env" ] && [ ! -f ".env" ]; then
    echo "Fehler: .env Datei nicht gefunden!"
    echo "Bitte ausführen von: ~/fin1-server"
    exit 1
fi

# Finde .env Datei
if [ -f "backend/.env" ]; then
    ENV_FILE="backend/.env"
elif [ -f ".env" ]; then
    ENV_FILE=".env"
else
    echo "Fehler: .env Datei nicht gefunden!"
    exit 1
fi

echo "✓ .env Datei gefunden: $ENV_FILE"
echo ""

# Backup erstellen
BACKUP_FILE="${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$ENV_FILE" "$BACKUP_FILE"
echo "✓ Backup erstellt: $BACKUP_FILE"
echo ""

# Generiere sichere Passwörter
echo "Generiere sichere Passwörter..."
PARSE_MASTER_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
MONGO_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

echo "✓ Passwörter generiert"
echo ""

# Aktualisiere .env Datei
echo "Aktualisiere .env Datei..."

# Parse Server Master Key
if grep -q "PARSE_SERVER_MASTER_KEY=" "$ENV_FILE"; then
    sed -i "s|PARSE_SERVER_MASTER_KEY=.*|PARSE_SERVER_MASTER_KEY=$PARSE_MASTER_KEY|g" "$ENV_FILE"
    echo "✓ PARSE_SERVER_MASTER_KEY aktualisiert"
fi

# MongoDB Password
if grep -q "MONGO_INITDB_ROOT_PASSWORD=" "$ENV_FILE"; then
    sed -i "s|MONGO_INITDB_ROOT_PASSWORD=.*|MONGO_INITDB_ROOT_PASSWORD=$MONGO_PASSWORD|g" "$ENV_FILE"
    echo "✓ MONGO_INITDB_ROOT_PASSWORD aktualisiert"

    # MongoDB URI aktualisieren
    sed -i "s|mongodb://admin:[^@]*@mongodb|mongodb://admin:$MONGO_PASSWORD@mongodb|g" "$ENV_FILE"
    sed -i "s|MONGODB_URI=.*|MONGODB_URI=mongodb://admin:$MONGO_PASSWORD@mongodb:27017/fin1?authSource=admin|g" "$ENV_FILE"
fi

# PostgreSQL Password
if grep -q "POSTGRES_PASSWORD=" "$ENV_FILE"; then
    sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|g" "$ENV_FILE"
    echo "✓ POSTGRES_PASSWORD aktualisiert"

    # PostgreSQL URL aktualisieren
    sed -i "s|postgresql://fin1_user:[^@]*@postgres|postgresql://fin1_user:$POSTGRES_PASSWORD@postgres|g" "$ENV_FILE"
    sed -i "s|POSTGRES_URL=.*|POSTGRES_URL=postgresql://fin1_user:$POSTGRES_PASSWORD@postgres:5432/fin1_analytics|g" "$ENV_FILE"
fi

# Redis Password
if grep -q "REDIS_PASSWORD=" "$ENV_FILE"; then
    sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$REDIS_PASSWORD|g" "$ENV_FILE"
    echo "✓ REDIS_PASSWORD aktualisiert"

    # Redis URL aktualisieren
    sed -i "s|redis://:[^@]*@redis|redis://:$REDIS_PASSWORD@redis|g" "$ENV_FILE"
    sed -i "s|REDIS_URL=.*|REDIS_URL=redis://:$REDIS_PASSWORD@redis:6379|g" "$ENV_FILE"
fi

# JWT Secret
if grep -q "JWT_SECRET=" "$ENV_FILE"; then
    sed -i "s|JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|g" "$ENV_FILE"
    echo "✓ JWT_SECRET aktualisiert"
fi

# Encryption Key
if grep -q "ENCRYPTION_KEY=" "$ENV_FILE"; then
    sed -i "s|ENCRYPTION_KEY=.*|ENCRYPTION_KEY=$ENCRYPTION_KEY|g" "$ENV_FILE"
    echo "✓ ENCRYPTION_KEY aktualisiert"
fi

# MinIO Passwords (falls vorhanden)
if grep -q "MINIO_ROOT_PASSWORD=" "$ENV_FILE"; then
    MINIO_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    sed -i "s|MINIO_ROOT_PASSWORD=.*|MINIO_ROOT_PASSWORD=$MINIO_PASSWORD|g" "$ENV_FILE"
    sed -i "s|S3_SECRET_KEY=.*|S3_SECRET_KEY=$MINIO_PASSWORD|g" "$ENV_FILE"
    echo "✓ MINIO_ROOT_PASSWORD aktualisiert"
fi

echo ""
echo "=========================================="
echo "✅ Fertig!"
echo "=========================================="
echo ""
echo "Alle Passwörter wurden automatisch generiert und gesetzt."
echo ""
echo "Backup wurde erstellt: $BACKUP_FILE"
echo ""
echo "Nächste Schritte:"
echo "  1. Server starten:"
echo "     cd ~/fin1-server"
echo "     docker compose -f docker-compose.production.yml up -d"
echo ""
echo "  2. Status prüfen:"
echo "     docker compose ps"
echo ""
echo "  3. Logs anzeigen:"
echo "     docker compose logs -f"
echo ""
echo "  4. Testen:"
echo "     curl http://192.168.178.20/health"
echo ""
