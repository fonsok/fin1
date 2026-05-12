#!/usr/bin/env bash
# =============================================================================
# Technischer Admin (Parse admin) und/oder Compliance-Portal-User anlegen oder Passwort setzen
#
# Nutzt dieselbe Cloud Function wie create-business-admin.sh: createAdminUser (Master-Key im Container).
# Passwörter nicht im Klartext ins Repo: Umgebungsvariablen oder scripts/.env.server (gitignored).
#
# Beispiele (nur technischer Admin):
#   TA_PASSWORD='<Passwort>' bash scripts/create-tech-compliance-admin.sh
#
# Nur Compliance:
#   CA_PASSWORD='<Passwort>' bash scripts/create-tech-compliance-admin.sh
#
# Beide in einem Lauf:
#   TA_PASSWORD='<…>' CA_PASSWORD='<…>' bash scripts/create-tech-compliance-admin.sh
#
# Eigene E-Mails:
#   TA_EMAIL=ops@fin1.de TA_PASSWORD='…' CA_EMAIL=legal@fin1.de CA_PASSWORD='…' bash …
#
# Optional: TA_PASSWORD / CA_PASSWORD in scripts/.env.server (siehe scripts/.env.server.example).
#
# Hinweise: accountLockout, maxPasswordHistory — wie create-business-admin.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_SERVER="${SCRIPT_DIR}/.env.server"
# Optional: TA_PASSWORD / CA_PASSWORD (and *_EMAIL) in gitignored operator env — same file as deploy.sh.
if [[ -f "${ENV_SERVER}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_SERVER}"
  set +a
fi

TA_EMAIL="${TA_EMAIL:-admin@fin1.de}"
TA_FIRST="${TA_FIRST:-Technical}"
TA_LAST="${TA_LAST:-Admin}"
CA_EMAIL="${CA_EMAIL:-compliance@fin1.de}"
CA_FIRST="${CA_FIRST:-Compliance}"
CA_LAST="${CA_LAST:-Officer}"

if [[ -z "${TA_PASSWORD:-}" && -z "${CA_PASSWORD:-}" ]]; then
  EXAMPLE="${SCRIPT_DIR}/.env.server.example"
  echo "Mindestens eines setzen: TA_PASSWORD (technischer Admin, Rolle admin) und/oder CA_PASSWORD (Compliance)." >&2
  echo "Beispiel:" >&2
  echo "  TA_PASSWORD='<Passwort>' bash scripts/create-tech-compliance-admin.sh" >&2
  echo "  TA_PASSWORD='<…>' CA_PASSWORD='<…>' bash scripts/create-tech-compliance-admin.sh" >&2
  if [[ -f "${EXAMPLE}" ]]; then
    echo "  — oder TA_PASSWORD / CA_PASSWORD in ${ENV_SERVER} (Vorlage: ${EXAMPLE})" >&2
  else
    echo "  — oder Variablen in ${ENV_SERVER} anlegen (Repo aktualisieren für .env.server.example)." >&2
  fi
  exit 1
fi

CONTAINER_NAME="${PARSE_CONTAINER_NAME:-fin1-parse-server}"

if ! command -v docker >/dev/null 2>&1 || ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q parse-server; then
  echo "Docker oder Parse-Container nicht gefunden." >&2
  echo "Auf dem Parse-Host: cd ~/fin1-server && TA_PASSWORD='…' bash scripts/create-tech-compliance-admin.sh" >&2
  exit 1
fi

echo "=== create-tech-compliance-admin ==="
[[ -n "${TA_PASSWORD:-}" ]] && echo "  Technischer Admin: ${TA_EMAIL} (Rolle admin)"
[[ -n "${CA_PASSWORD:-}" ]] && echo "  Compliance:        ${CA_EMAIL} (Rolle compliance)"
echo ""

docker exec \
  -e TA_EMAIL="$TA_EMAIL" \
  -e TA_PASSWORD="${TA_PASSWORD:-}" \
  -e TA_FIRST="$TA_FIRST" \
  -e TA_LAST="$TA_LAST" \
  -e CA_EMAIL="$CA_EMAIL" \
  -e CA_PASSWORD="${CA_PASSWORD:-}" \
  -e CA_FIRST="$CA_FIRST" \
  -e CA_LAST="$CA_LAST" \
  "$CONTAINER_NAME" node -e "
    const Parse = require('parse/node');
    Parse.initialize(process.env.PARSE_SERVER_APPLICATION_ID, null, process.env.PARSE_SERVER_MASTER_KEY);
    Parse.serverURL = 'http://localhost:1337/parse';
    (async () => {
      try {
        if (process.env.TA_PASSWORD) {
          const r = await Parse.Cloud.run('createAdminUser', {
            email: process.env.TA_EMAIL,
            password: process.env.TA_PASSWORD,
            firstName: process.env.TA_FIRST,
            lastName: process.env.TA_LAST,
            role: 'admin',
            forcePasswordReset: true,
          }, { useMasterKey: true });
          console.log('--- technical admin (admin) ---');
          console.log(JSON.stringify(r, null, 2));
        }
        if (process.env.CA_PASSWORD) {
          const r = await Parse.Cloud.run('createAdminUser', {
            email: process.env.CA_EMAIL,
            password: process.env.CA_PASSWORD,
            firstName: process.env.CA_FIRST,
            lastName: process.env.CA_LAST,
            role: 'compliance',
            forcePasswordReset: true,
          }, { useMasterKey: true });
          console.log('--- compliance ---');
          console.log(JSON.stringify(r, null, 2));
        }
      } catch (e) {
        console.error('Fehler:', e.message);
        process.exit(1);
      }
    })();
  "

echo ""
echo "========================================"
echo " Fertig (Passwörter nicht erneut ausgegeben)"
echo "========================================"
echo "  Portal: https://192.168.178.24/admin/login"
echo ""
