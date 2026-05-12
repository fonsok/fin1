#!/usr/bin/env bash
# =============================================================================
# Portal-Login zurücksetzen (Admin, Finance Admin, Security, Compliance, CSR)
#
# Setzt Passwort immer neu, status active, hebt Parse-Account-Lockout auf.
# Cloud Function: resetPortalUserCredentialsMaster (nur Master-Key).
#
# Auf dem Parse-Host ausführen (Docker):
#   cd ~/fin1-server
#   bash scripts/reset-portal-login.sh finance@fin1.de 'NeuesStarkesPasswort!9'
#
# Oder per Umgebungsvariablen:
#   EMAIL=admin@fin1.de PASSWORD='<NeuesPasswort>' ROLE=admin bash scripts/reset-portal-login.sh
#
# ROLE standardmäßig: business_admin (für finance@…); für admin@ explizit ROLE=admin setzen.
# Bootstrap statt Einzel-Reset: scripts/create-business-admin.sh | create-tech-admin.sh | create-compliance-admin.sh (jeweils BA_PASSWORD=…).
# =============================================================================

set -e

CONTAINER_NAME="${PARSE_CONTAINER_NAME:-fin1-parse-server}"
EMAIL="${1:-${EMAIL:-finance@fin1.de}}"
PASSWORD="${2:-$PASSWORD}"
ROLE="${ROLE:-business_admin}"

if [ -z "$PASSWORD" ]; then
  echo "Fehlt: Passwort"
  echo ""
  echo "Beispiel Finance Admin:"
  echo "  bash scripts/reset-portal-login.sh finance@fin1.de 'IhrNeuesPasswort!9'"
  echo ""
  echo "Beispiel Technischer Admin:"
  echo "  ROLE=admin bash scripts/reset-portal-login.sh admin@fin1.de 'IhrNeuesPasswort!9'"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1 || ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q parse-server; then
  echo "Docker oder Parse-Container nicht gefunden."
  echo "Auf dem Server: cd ~/fin1-server && bash scripts/reset-portal-login.sh …"
  exit 1
fi

echo "Reset Portal-Login: $EMAIL (Rolle: $ROLE)"
docker exec \
  -e R_EMAIL="$EMAIL" \
  -e R_PASSWORD="$PASSWORD" \
  -e R_ROLE="$ROLE" \
  "$CONTAINER_NAME" node -e "
    const Parse = require('parse/node');
    Parse.initialize(process.env.PARSE_SERVER_APPLICATION_ID, null, process.env.PARSE_SERVER_MASTER_KEY);
    Parse.serverURL = 'http://localhost:1337/parse';
    Parse.Cloud.run('resetPortalUserCredentialsMaster', {
      email: process.env.R_EMAIL,
      password: process.env.R_PASSWORD,
      role: process.env.R_ROLE,
    }, { useMasterKey: true })
      .then((r) => { console.log(JSON.stringify(r, null, 2)); })
      .catch((e) => { console.error('Fehler:', e.message); process.exit(1); });
  "

echo ""
echo "Fertig. Anmeldung im Admin-Portal mit neuer E-Mail/Passwort-Kombination testen."
