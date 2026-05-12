#!/usr/bin/env bash
# Fügt businessCaseId (String) zu Parse-Klassen Investment und Document hinzu (Master-Key).
# Investment: "Permission denied for action addField on class Investment" bei Saves mit businessCaseId.
# Document: Reservierungs-Eigenbeleg setzt businessCaseId — ohne Schema-Spalte keine Buchung CLT-LIAB-RSV.
#
# Voraussetzung: PARSE_SERVER_APPLICATION_ID, PARSE_SERVER_MASTER_KEY
# Optional: PARSE_SERVER_URL — Basis inkl. /parse, z. B. https://ihre-domain/parse oder http://127.0.0.1:1337/parse
# Vorrang: per export gesetzte PARSE_*-Werte (nicht leer) überschreiben backend/.env — siehe _SAVE_* unten.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Werte, die du VOR dem Script per export setzt, sollen nicht von backend/.env überschrieben werden
# (lokale Template-.env hat oft anderen/leeren Master-Key → sonst „master key is required“).
_SAVE_PARSE_SERVER_URL="${PARSE_SERVER_URL:-}"
_SAVE_PARSE_SERVER_PUBLIC_SERVER_URL="${PARSE_SERVER_PUBLIC_SERVER_URL:-}"
_SAVE_PARSE_SERVER_APPLICATION_ID="${PARSE_SERVER_APPLICATION_ID:-}"
_SAVE_PARSE_SERVER_MASTER_KEY="${PARSE_SERVER_MASTER_KEY:-}"

# shellcheck disable=SC1090
set -a
if [[ -f "$ROOT/backend/.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/backend/.env"
fi
if [[ -f "$ROOT/backend/parse-server/.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/backend/parse-server/.env"
fi
set +a

[[ -n "$_SAVE_PARSE_SERVER_URL" ]] && PARSE_SERVER_URL="$_SAVE_PARSE_SERVER_URL"
[[ -n "$_SAVE_PARSE_SERVER_PUBLIC_SERVER_URL" ]] && PARSE_SERVER_PUBLIC_SERVER_URL="$_SAVE_PARSE_SERVER_PUBLIC_SERVER_URL"
[[ -n "$_SAVE_PARSE_SERVER_APPLICATION_ID" ]] && PARSE_SERVER_APPLICATION_ID="$_SAVE_PARSE_SERVER_APPLICATION_ID"
[[ -n "$_SAVE_PARSE_SERVER_MASTER_KEY" ]] && PARSE_SERVER_MASTER_KEY="$_SAVE_PARSE_SERVER_MASTER_KEY"

# Öffentliche Parse-URL aus .env nutzen, wenn PARSE_SERVER_URL nicht gesetzt ist
if [[ -z "${PARSE_SERVER_URL:-}" && -n "${PARSE_SERVER_PUBLIC_SERVER_URL:-}" ]]; then
  PARSE_SERVER_URL="$PARSE_SERVER_PUBLIC_SERVER_URL"
fi
# Ohne PARSE_SERVER_URL: Standard 1337. Docker-Compose (FIN1) exponiert oft 1338 — dann
# PARSE_SERVER_URL=http://127.0.0.1:1338/parse setzen oder in backend/.env eintragen.
BASE="${PARSE_SERVER_URL:-http://127.0.0.1:1337/parse}"
BASE="${BASE%/}"
APP_ID="${PARSE_SERVER_APPLICATION_ID:?Set PARSE_SERVER_APPLICATION_ID}"
MASTER="${PARSE_SERVER_MASTER_KEY:?Set PARSE_SERVER_MASTER_KEY}"

# Optional: PARSE_CURL_INSECURE=1 bei HTTPS mit selbstsigniertem Zertifikat → curl -k
# Hinweis: Bash 3.2 + set -u: leeres "${CURL_TLS[@]}" ist „unbound“ — daher ${…+…}-Muster.
CURL_TLS=()
if [[ "${PARSE_CURL_INSECURE:-}" == "1" ]]; then
  CURL_TLS+=(-k)
fi

echo "PUT ${BASE}/schemas/Investment (businessCaseId: String)"
# shellcheck disable=SC2086 # absichtlich: optionales -k als eigenes curl-Argument
curl -sS ${CURL_TLS[@]+"${CURL_TLS[@]}"} -X PUT "${BASE}/schemas/Investment" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "X-Parse-Master-Key: ${MASTER}" \
  -H "Content-Type: application/json" \
  -d '{"className":"Investment","fields":{"businessCaseId":{"type":"String"}}}'
echo ""
echo "PUT ${BASE}/schemas/Document (businessCaseId, accountingSummaryText: String)"
curl -sS ${CURL_TLS[@]+"${CURL_TLS[@]}"} -X PUT "${BASE}/schemas/Document" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "X-Parse-Master-Key: ${MASTER}" \
  -H "Content-Type: application/json" \
  -d '{"className":"Document","fields":{"businessCaseId":{"type":"String"},"accountingSummaryText":{"type":"String"}}}'
echo ""
echo "OK: Schema-Updates angefordert."
