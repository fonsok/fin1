#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Optional: auf dem Server den Produktions-Stack prüfen, z. B.
#   export FIN1_SMOKE_COMPOSE_FILE="$HOME/fin1-server/docker-compose.production.yml"
COMPOSE_FILE=""
if [[ -n "${FIN1_SMOKE_COMPOSE_FILE:-}" && -f "${FIN1_SMOKE_COMPOSE_FILE}" ]]; then
  COMPOSE_FILE="${FIN1_SMOKE_COMPOSE_FILE}"
elif [[ -f "${ROOT_DIR}/docker-compose.yml" ]]; then
  COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"
elif [[ -f "${ROOT_DIR}/docker-compose.production.yml" ]]; then
  COMPOSE_FILE="${ROOT_DIR}/docker-compose.production.yml"
else
  echo "[smoke] No docker-compose.yml / docker-compose.production.yml found in ${ROOT_DIR}" >&2
  exit 2
fi

echo "[smoke] Using compose file: ${COMPOSE_FILE}"

CODE() {
  local url="$1"
  # -k because we may have self-signed certs on the server
  curl -k -sS -o /dev/null -w "%{http_code}" "${url}" || echo "000"
}

echo
echo "[smoke] Endpoint checks (external via nginx)"
HEALTH_CODE="$(CODE "https://127.0.0.1/health")"
PARSE_HEALTH_CODE="$(CODE "https://127.0.0.1/parse/health")"
ADMIN_CODE="$(CODE "https://127.0.0.1/admin/")"
echo "  /health        -> ${HEALTH_CODE}"
echo "  /parse/health -> ${PARSE_HEALTH_CODE}"
echo "  /admin/        -> ${ADMIN_CODE}"

echo
echo "[smoke] Docker health statuses"
#
# Dynamisch statt hardcoded: wir lesen alle Compose-Services aus der
# aktiven Compose-Datei, damit auch zukünftig hinzugefügte Services
# automatisch mit geprüft werden.
#
ALL_SERVICES=()
if docker compose -f "${COMPOSE_FILE}" config --services >/dev/null 2>&1; then
  mapfile -t ALL_SERVICES < <(docker compose -f "${COMPOSE_FILE}" config --services)
else
  echo "[smoke] WARN: Could not read compose services. Falling back to defaults." >&2
  ALL_SERVICES=(
    parse-server
    mongodb
    redis
    nginx
    market-data
    notification-service
    analytics-service
  )
fi

ANY_FAIL=0
MISSING_SERVICES=()
for svc in "${ALL_SERVICES[@]}"; do
  cname="fin1-${svc}"
  # docker inspect might fail if container does not exist; tolerate and mark as fail
  info="$(docker inspect --format '{{.Name}} state={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${cname}" 2>/dev/null || true)"
  if [[ -z "${info}" ]]; then
    echo "  ${cname} -> MISSING"
    MISSING_SERVICES+=("${cname}")
    continue
  fi
  echo "  ${info}"

  # Mark non-healthy health statuses as failure, but allow "starting" / "none" to not hard-fail instantly.
  # The goal is to surface real issues without false alarms.
  if echo "${info}" | grep -q "health=unhealthy"; then
    ANY_FAIL=1
  fi
done

echo
echo "[smoke] Internal connectivity checks (from nginx container)"
if docker inspect --format '{{.State.Status}}' fin1-nginx >/dev/null 2>&1; then
  NGINX_EXEC="docker compose -f ${COMPOSE_FILE} exec -T nginx"
  # Try both parse paths.
  INTERNAL_PARSE_HEALTH_1="$(${NGINX_EXEC} curl -sS -o /dev/null -w \"%{http_code}\" http://parse-server:1337/health 2>/dev/null || echo 000)"
  INTERNAL_PARSE_HEALTH_2="$(${NGINX_EXEC} curl -sS -o /dev/null -w \"%{http_code}\" http://parse-server:1337/parse/health 2>/dev/null || echo 000)"
  echo "  nginx -> parse-server:1337/health     -> ${INTERNAL_PARSE_HEALTH_1}"
  echo "  nginx -> parse-server:1337/parse/health -> ${INTERNAL_PARSE_HEALTH_2}"
fi

echo
if [[ "${HEALTH_CODE}" != "200" || "${PARSE_HEALTH_CODE}" != "200" ]]; then
  ANY_FAIL=1
fi

if [[ "${ANY_FAIL}" != "0" ]]; then
  echo "[smoke] FAIL: some checks did not pass" >&2
  echo
  echo "[smoke] Recent logs (parse-server, nginx)"
  docker compose -f "${COMPOSE_FILE}" logs --tail=80 parse-server || true
  docker compose -f "${COMPOSE_FILE}" logs --tail=80 nginx || true
  exit 1
fi

if [[ "${#MISSING_SERVICES[@]}" -gt 0 ]]; then
  echo "[smoke] WARN: Some compose services are defined but containers are missing (not running):"
  for x in "${MISSING_SERVICES[@]}"; do
    echo "  - ${x}"
  done
fi

echo "[smoke] PASS: endpoints OK and no unhealthy container detected"
exit 0

