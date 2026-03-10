#!/usr/bin/env bash
# Admin-Portal-Login zurücksetzen (Passwort für admin@fin1.de setzen)
#
# Auf dem Server ausführen (aus dem Projekt-Root, z.B. ~/fin1-server oder FIN1):
#   bash scripts/reset-admin-login.sh
#
# Eigenes Passwort:
#   ADMIN_PASSWORD="MeinSicheresPasswort" bash scripts/reset-admin-login.sh

set -e
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@fin1.de}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-AdminLogin2025!}"

# Container-Name (Docker Compose setzt oft ein Prefix)
CONTAINER_NAME="${PARSE_CONTAINER_NAME:-fin1-parse-server}"

if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -q parse-server; then
  echo "Setze Admin-Login zurück: $ADMIN_EMAIL"
  docker exec -e ADMIN_EMAIL -e ADMIN_PASSWORD "$CONTAINER_NAME" node -e "
    const Parse = require('parse/node');
    Parse.initialize(process.env.PARSE_SERVER_APPLICATION_ID, null, process.env.PARSE_SERVER_MASTER_KEY);
    Parse.serverURL = 'http://localhost:1337/parse';
    Parse.Cloud.run('createAdminUser', {
      email: process.env.ADMIN_EMAIL || 'admin@fin1.de',
      password: process.env.ADMIN_PASSWORD || 'AdminLogin2025!',
      firstName: 'Admin',
      lastName: 'User',
      forcePasswordReset: true
    }, { useMasterKey: true })
      .then(r => { console.log(JSON.stringify(r, null, 2)); })
      .catch(e => { console.error('Fehler:', e.message); process.exit(1); });
  "
  echo ""
  echo "Fertig. Anmeldung im Admin-Portal:"
  echo "  URL:      https://192.168.178.24/admin/"
  echo "  E-Mail:   $ADMIN_EMAIL"
  echo "  Passwort: $ADMIN_PASSWORD"
else
  echo "Docker oder Parse-Container nicht gefunden."
  echo "Auf dem Server ausführen (dort wo fin1-server läuft):"
  echo "  cd ~/fin1-server"
  echo "  bash scripts/reset-admin-login.sh"
  echo ""
  echo "Oder manuell (Master-Key aus backend/.env):"
  echo "  curl -sk -X POST https://192.168.178.24/parse/functions/createAdminUser \\"
  echo "    -H 'X-Parse-Application-Id: fin1-app-id' \\"
  echo "    -H 'X-Parse-Master-Key: DEIN_MASTER_KEY' \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"email\":\"admin@fin1.de\",\"password\":\"AdminLogin2025!\",\"forcePasswordReset\":true}'"
  exit 1
fi
