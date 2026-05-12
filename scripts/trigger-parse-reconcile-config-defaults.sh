#!/usr/bin/env bash
# Trigger Parse Cloud function `reconcileConfigDefaults` on the fin1-server host.
# Uses `docker exec` + `node -` so PARSE_SERVER_* secrets stay inside the container
# (avoids broken curl + `$VAR` quoting over nested SSH).
#
# Usage:
#   ./scripts/trigger-parse-reconcile-config-defaults.sh
#   ./scripts/trigger-parse-reconcile-config-defaults.sh io@192.168.178.20
#
# Optional: FIN1_PARSE_CONTAINER (default: fin1-parse-server)

set -euo pipefail

REMOTE="${1:-io@192.168.178.20}"
CONTAINER="${FIN1_PARSE_CONTAINER:-fin1-parse-server}"

ssh -o BatchMode=yes "$REMOTE" docker exec -i "$CONTAINER" node - <<'NODE'
const http = require('http');
const id = process.env.PARSE_SERVER_APPLICATION_ID;
const mk = process.env.PARSE_SERVER_MASTER_KEY;
if (!id || !mk) {
  console.error('Missing PARSE_SERVER_APPLICATION_ID or PARSE_SERVER_MASTER_KEY in container env');
  process.exit(1);
}
const opts = {
  hostname: '127.0.0.1',
  port: 1337,
  path: '/parse/functions/reconcileConfigDefaults',
  method: 'POST',
  headers: {
    'X-Parse-Application-Id': id,
    'X-Parse-Master-Key': mk,
    'Content-Type': 'application/json',
  },
};
const req = http.request(opts, (res) => {
  let body = '';
  res.on('data', (c) => { body += c; });
  res.on('end', () => {
    console.log('HTTP', res.statusCode);
    console.log(body);
    process.exit(res.statusCode === 200 ? 0 : 1);
  });
});
req.on('error', (err) => {
  console.error(err.message);
  process.exit(1);
});
req.write('{}');
req.end();
NODE
