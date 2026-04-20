#!/usr/bin/env bash
set -euo pipefail

# FIN1 return-percentage contract monitor (server-local wrapper).
# - Runs the mongosh monitor script
# - Fails if missingReturnPercentageCount > threshold
# - Optionally sends Slack alert when breached

BASE_DIR="${BASE_DIR:-/home/io/fin1-server}"
BACKEND_DIR="$BASE_DIR/backend"
COMPOSE_FILE="${COMPOSE_FILE:-$BASE_DIR/docker-compose.production.yml}"
MONITOR_ENV_FILE="${MONITOR_ENV_FILE:-$BASE_DIR/scripts/monitor.env}"

# Optional operator config file (no spaces around '='):
#   MONITOR_THRESHOLD=0
#   MAX_AGE_SECONDS=90000
#   RETURN_MONITOR_SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
if [[ -f "$MONITOR_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$MONITOR_ENV_FILE"
  set +a
fi

THRESHOLD="${MONITOR_THRESHOLD:-0}"
SLACK_WEBHOOK_URL="${RETURN_MONITOR_SLACK_WEBHOOK_URL:-}"
ALERT_EMAIL_TO="${RETURN_MONITOR_ALERT_EMAIL_TO:-}"
ALERT_EMAIL_FROM="${RETURN_MONITOR_ALERT_EMAIL_FROM:-fin1-monitor@localhost}"
STATE_FILE="${STATE_FILE:-$BASE_DIR/logs/return-monitor.last-run}"
HEARTBEAT_FILE="${HEARTBEAT_FILE:-$BASE_DIR/logs/return-monitor.heartbeat}"
ALERT_FILE="${ALERT_FILE:-$BASE_DIR/logs/return-monitor.alert}"
MAX_AGE_SECONDS="${MAX_AGE_SECONDS:-90000}" # 25h
FORCE_BREACH="${RETURN_MONITOR_FORCE_BREACH:-0}" # set to 1 for alert pipeline test
CATCHUP_MODE="false"

if [[ "${1:-}" == "--catchup" ]]; then
  CATCHUP_MODE="true"
fi

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
epoch_now() { date -u +%s; }

if [[ ! -f "$BACKEND_DIR/.env" ]]; then
  echo "[$(timestamp)] ERROR: Missing env file: $BACKEND_DIR/.env"
  exit 2
fi

MONGO_PASSWORD="$(python3 - <<'PY'
from pathlib import Path
env = {}
for raw in Path("/home/io/fin1-server/backend/.env").read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    k, v = line.split("=", 1)
    env[k.strip()] = v
print(env.get("MONGO_INITDB_ROOT_PASSWORD", ""))
PY
)"

SMTP_SETTINGS="$(python3 - <<'PY'
from pathlib import Path
env = {}
for raw in Path("/home/io/fin1-server/backend/.env").read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    k, v = line.split("=", 1)
    env[k.strip()] = v
print(env.get("SMTP_HOST", ""))
print(env.get("SMTP_PORT", "587"))
print(env.get("SMTP_USER", ""))
print(env.get("SMTP_PASS", ""))
print(env.get("SMTP_SECURE", "false"))
PY
)"
SMTP_HOST="$(printf '%s\n' "$SMTP_SETTINGS" | sed -n '1p')"
SMTP_PORT="$(printf '%s\n' "$SMTP_SETTINGS" | sed -n '2p')"
SMTP_USER="$(printf '%s\n' "$SMTP_SETTINGS" | sed -n '3p')"
SMTP_PASS="$(printf '%s\n' "$SMTP_SETTINGS" | sed -n '4p')"
SMTP_SECURE="$(printf '%s\n' "$SMTP_SETTINGS" | sed -n '5p')"

if [[ -z "$MONGO_PASSWORD" ]]; then
  echo "[$(timestamp)] ERROR: MONGO_INITDB_ROOT_PASSWORD not found in .env"
  exit 2
fi

if [[ "$CATCHUP_MODE" == "true" && -f "$STATE_FILE" ]]; then
  LAST_RUN_EPOCH="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
  NOW_EPOCH="$(epoch_now)"
  AGE=$(( NOW_EPOCH - LAST_RUN_EPOCH ))
  if (( AGE >= 0 && AGE < MAX_AGE_SECONDS )); then
    echo "[$(timestamp)] SKIP: catch-up not needed (last run ${AGE}s ago, max=${MAX_AGE_SECONDS}s)"
    exit 0
  fi
fi

RAW_OUTPUT="$(
  cd "$BASE_DIR" && docker compose -f "$COMPOSE_FILE" exec -T mongodb \
    mongosh --quiet --username admin --password "$MONGO_PASSWORD" --authenticationDatabase admin fin1 --eval '
const coll = db.getCollection("Document");
const baseQuery = {
  type: { $in: ["investorCollectionBill", "investor_collection_bill"] },
  "metadata.receiptType": { $exists: false }
};
const missingQuery = {
  ...baseQuery,
  $or: [
    { "metadata.returnPercentage": { $exists: false } },
    { "metadata.returnPercentage": null }
  ]
};
const totalActive = coll.countDocuments(baseQuery);
const missingCount = coll.countDocuments(missingQuery);
print("totalActiveCollectionBills=" + totalActive);
print("missingReturnPercentageCount=" + missingCount);
print("healthy=" + (missingCount === 0));
'
)"

echo "$RAW_OUTPUT"

MISSING_COUNT="$(printf '%s\n' "$RAW_OUTPUT" | awk -F= '/missingReturnPercentageCount=/{print $2}' | tr -d '[:space:]' | tail -n1)"
TOTAL_ACTIVE="$(printf '%s\n' "$RAW_OUTPUT" | awk -F= '/totalActiveCollectionBills=/{print $2}' | tr -d '[:space:]' | tail -n1)"

if [[ -z "$MISSING_COUNT" ]]; then
  echo "[$(timestamp)] ERROR: Could not parse missingReturnPercentageCount from monitor output"
  exit 2
fi

# Safe test mode: force alert path without mutating DB documents.
if [[ "$FORCE_BREACH" == "1" ]]; then
  MISSING_COUNT=$(( THRESHOLD + 1 ))
  echo "[$(timestamp)] INFO: RETURN_MONITOR_FORCE_BREACH enabled; forcing missing=${MISSING_COUNT}"
fi

if (( MISSING_COUNT > THRESHOLD )); then
  MESSAGE="FIN1 Return% monitor breach: missing=${MISSING_COUNT}, total=${TOTAL_ACTIVE:-unknown}, threshold=${THRESHOLD}, checkedAt=$(timestamp)"
  echo "[$(timestamp)] ALERT: $MESSAGE"
  printf 'status=alert checked_at=%s missing=%s total=%s threshold=%s\n' "$(timestamp)" "$MISSING_COUNT" "${TOTAL_ACTIVE:-unknown}" "$THRESHOLD" > "$ALERT_FILE"
  if command -v logger >/dev/null 2>&1; then
    logger -t fin1-return-monitor -- "$MESSAGE" || true
  fi

  if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
    payload="$(printf '{"text":"%s"}' "$MESSAGE")"
    curl -sS -X POST "$SLACK_WEBHOOK_URL" -H "Content-Type: application/json" --data "$payload" >/dev/null || true
  fi

  if [[ -n "$ALERT_EMAIL_TO" ]]; then
    SUBJECT="[FIN1][ALERT] Return% contract breach"
    BODY="$MESSAGE"
    if command -v mail >/dev/null 2>&1; then
      printf '%s\n' "$BODY" | mail -r "$ALERT_EMAIL_FROM" -s "$SUBJECT" "$ALERT_EMAIL_TO" || true
    elif command -v mailx >/dev/null 2>&1; then
      printf '%s\n' "$BODY" | mailx -r "$ALERT_EMAIL_FROM" -s "$SUBJECT" "$ALERT_EMAIL_TO" || true
    elif [[ -n "$SMTP_HOST" && -n "$SMTP_USER" && -n "$SMTP_PASS" ]]; then
      SMTP_HOST="$SMTP_HOST" SMTP_PORT="$SMTP_PORT" SMTP_USER="$SMTP_USER" SMTP_PASS="$SMTP_PASS" SMTP_SECURE="$SMTP_SECURE" \
      ALERT_EMAIL_TO="$ALERT_EMAIL_TO" ALERT_EMAIL_FROM="$ALERT_EMAIL_FROM" ALERT_SUBJECT="$SUBJECT" ALERT_BODY="$BODY" \
      python3 - <<'PY' || true
import os
import smtplib
from email.message import EmailMessage

host = os.environ.get("SMTP_HOST", "")
port = int(os.environ.get("SMTP_PORT", "587"))
user = os.environ.get("SMTP_USER", "")
password = os.environ.get("SMTP_PASS", "")
secure = os.environ.get("SMTP_SECURE", "false").lower() == "true"
to_addr = os.environ.get("ALERT_EMAIL_TO", "")
from_addr = os.environ.get("ALERT_EMAIL_FROM", user or "fin1-monitor@localhost")
subject = os.environ.get("ALERT_SUBJECT", "[FIN1] Alert")
body = os.environ.get("ALERT_BODY", "")

msg = EmailMessage()
msg["Subject"] = subject
msg["From"] = from_addr
msg["To"] = to_addr
msg.set_content(body)

if secure:
    with smtplib.SMTP_SSL(host, port, timeout=20) as server:
        server.login(user, password)
        server.send_message(msg)
else:
    with smtplib.SMTP(host, port, timeout=20) as server:
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(user, password)
        server.send_message(msg)
print("SMTP alert email sent")
PY
    else
      echo "[$(timestamp)] WARN: email alert requested but no mail binary and SMTP env not configured"
    fi
  fi

  exit 1
fi

mkdir -p "$(dirname "$STATE_FILE")"
epoch_now > "$STATE_FILE"
printf 'status=ok checked_at=%s missing=%s total=%s threshold=%s\n' "$(timestamp)" "$MISSING_COUNT" "${TOTAL_ACTIVE:-unknown}" "$THRESHOLD" > "$HEARTBEAT_FILE"
echo "[$(timestamp)] OK: missing=${MISSING_COUNT}, total=${TOTAL_ACTIVE:-unknown}, threshold=${THRESHOLD}"
exit 0
