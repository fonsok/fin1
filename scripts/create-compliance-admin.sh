#!/usr/bin/env bash
# ===========================================================================
# Compliance-Portal-Admin (Parse-Rolle compliance) — gleiche Login-URL wie andere Admins
#
# Standard-E-Mail: compliance@fin1.de (bei Bedarf überschreiben mit BA_EMAIL=…).
#
# Auf dem Parse-Host ausführen:
#   BA_PASSWORD='…' bash scripts/create-compliance-admin.sh
#   — oder BA_PASSWORD in scripts/.env.server (gitignored), siehe scripts/.env.server.example
#
# Andere E-Mail / Namen:
#   BA_EMAIL="compliance-officer@fin1.de" BA_PASSWORD="<IhrPasswort>" bash scripts/create-compliance-admin.sh
#
# Hinweise: wie create-business-admin.sh (accountLockout, maxPasswordHistory, forcePasswordReset).
# ===========================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_SERVER="${SCRIPT_DIR}/.env.server"
if [[ -z "${BA_PASSWORD:-}" && -f "${ENV_SERVER}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_SERVER}"
  set +a
fi

BA_EMAIL="${BA_EMAIL:-compliance@fin1.de}"
if [[ -z "${BA_PASSWORD:-}" ]]; then
  EXAMPLE="${SCRIPT_DIR}/.env.server.example"
  echo "BA_PASSWORD muss gesetzt sein. Beispiele:" >&2
  echo "  BA_PASSWORD='<IhrPasswort>' bash scripts/create-compliance-admin.sh" >&2
  if [[ -f "${EXAMPLE}" ]]; then
    echo "  — oder: cp ${EXAMPLE} ${ENV_SERVER} && nano ${ENV_SERVER}   # BA_PASSWORD=… eintragen" >&2
  else
    echo "  — oder: ${ENV_SERVER} anlegen mit mindestens: BA_PASSWORD=…" >&2
    echo "  (scripts/.env.server.example fehlt — Repo auf dem Host aktualisieren.)" >&2
  fi
  exit 1
fi
BA_FIRST="${BA_FIRST:-Compliance}"
BA_LAST="${BA_LAST:-Officer}"
CONTAINER_NAME="${PARSE_CONTAINER_NAME:-fin1-parse-server}"

if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -q parse-server; then
  echo "Erstelle / setze Compliance-Admin: $BA_EMAIL (Rolle: compliance)"
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
      role: 'compliance',
      forcePasswordReset: true
    }, { useMasterKey: true })
      .then(r => { console.log(JSON.stringify(r, null, 2)); })
      .catch(e => { console.error('Fehler:', e.message); process.exit(1); });
  "
  echo ""
  echo "========================================"
  echo " Compliance-Admin — fertig"
  echo "========================================"
  echo ""
  echo "  Login-URL:  (siehe WEB_PANEL_LOGIN_CREDENTIALS.md)"
  echo "  E-Mail:     $BA_EMAIL"
  echo "  Passwort:   (gesetzt; nicht erneut ausgegeben)"
  echo "  Rolle:      compliance"
  echo ""
else
  echo "Docker oder Parse-Container nicht gefunden."
  echo "  cd ~/fin1-server && BA_PASSWORD='<IhrPasswort>' bash scripts/create-compliance-admin.sh"
  exit 1
fi
