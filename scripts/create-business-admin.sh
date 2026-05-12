#!/usr/bin/env bash
# ===========================================================================
# Finance Admin (Parse-Rolle business_admin) — gleiche Portal-Login-URL wie Technischer Admin
#
# Vorgesehene Demo-Mail: finance@fin1.de (siehe admin-portal/src/constants/portalLogin.ts).
# 4-Augen-Prinzip typisch:
#   - admin@fin1.de      -> beantragt Konfigurationsänderungen
#   - finance@fin1.de    -> genehmigt oder lehnt ab (und umgekehrt)
#
# Auf dem Server ausführen:
#   bash scripts/create-business-admin.sh
#
# Nur Passwort/Login reparieren (Lockout + neues Passwort):
#   bash scripts/reset-portal-login.sh finance@fin1.de 'NeuesPasswort!9'
#
# Eigene Zugangsdaten:
#   BA_EMAIL="cfo@fin1.de" BA_PASSWORD="MeinPasswort!" bash scripts/create-business-admin.sh
#
# Hinweise:
#   - Parse accountLockout: nach 3 Fehlversuchen ca. 5 Minuten Sperre (backend/parse-server/index.js).
#   - Existiert der User schon, wird das Passwort nur bei forcePasswordReset oder Rollenwechsel gesetzt.
#   - Neues Passwort darf nicht einer der letzten 5 Passwörter sein (maxPasswordHistory).
# ===========================================================================

set -e

BA_EMAIL="${BA_EMAIL:-finance@fin1.de}"
BA_PASSWORD="${BA_PASSWORD:-Finance2026!}"
BA_FIRST="${BA_FIRST:-Finance}"
BA_LAST="${BA_LAST:-Admin}"
CONTAINER_NAME="${PARSE_CONTAINER_NAME:-fin1-parse-server}"

if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -q parse-server; then
  echo "Erstelle Business-Admin: $BA_EMAIL (Rolle: business_admin)"
  docker exec \
    -e BA_EMAIL="$BA_EMAIL" \
    -e BA_PASSWORD="$BA_PASSWORD" \
    -e BA_FIRST="$BA_FIRST" \
    -e BA_LAST="$BA_LAST" \
    "$CONTAINER_NAME" node -e "
    const Parse = require('parse/node');
    Parse.initialize(process.env.PARSE_SERVER_APPLICATION_ID, null, process.env.PARSE_SERVER_MASTER_KEY);
    Parse.serverURL = 'http://localhost:1337/parse';
    Parse.Cloud.run('createAdminUser', {
      email: process.env.BA_EMAIL,
      password: process.env.BA_PASSWORD,
      firstName: process.env.BA_FIRST,
      lastName: process.env.BA_LAST,
      role: 'business_admin',
      forcePasswordReset: true
    }, { useMasterKey: true })
      .then(r => { console.log(JSON.stringify(r, null, 2)); })
      .catch(e => { console.error('Fehler:', e.message); process.exit(1); });
  "
  echo ""
  echo "========================================"
  echo " Business-Admin erfolgreich angelegt"
  echo "========================================"
  echo ""
  echo "  Login-URL:  https://192.168.178.24/admin/"
  echo "  E-Mail:     $BA_EMAIL"
  echo "  Passwort:   $BA_PASSWORD"
  echo "  Rolle:      business_admin"
  echo ""
  echo "  Berechtigungen:"
  echo "    - Konfigurationsänderungen beantragen & genehmigen"
  echo "    - Finanzberichte & Accounting"
  echo "    - 4-Augen-Freigaben"
  echo "    - Audit-Logs lesen"
  echo ""
  echo "  4-Augen-Workflow:"
  echo "    admin@fin1.de beantragt  -> finance@fin1.de genehmigt"
  echo "    finance@fin1.de beantragt -> admin@fin1.de genehmigt"
  echo ""
else
  echo "Docker oder Parse-Container nicht gefunden."
  echo ""
  echo "Auf dem Server ausführen:"
  echo "  cd ~/fin1-server && bash scripts/create-business-admin.sh"
  echo ""
  echo "Oder manuell per curl (Master-Key aus backend/.env):"
  echo ""
  echo "  curl -sk -X POST https://192.168.178.24/parse/functions/createAdminUser \\"
  echo "    -H 'X-Parse-Application-Id: fin1-app-id' \\"
  echo "    -H 'X-Parse-Master-Key: DEIN_MASTER_KEY' \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"email\":\"$BA_EMAIL\",\"password\":\"$BA_PASSWORD\",\"firstName\":\"$BA_FIRST\",\"lastName\":\"$BA_LAST\",\"role\":\"business_admin\",\"forcePasswordReset\":true}'"
  exit 1
fi
