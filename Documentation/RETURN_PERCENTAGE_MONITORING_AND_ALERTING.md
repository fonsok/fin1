# Return Percentage Monitoring & Alerting

## Goal
Detect any active investor collection bill without canonical `metadata.returnPercentage` early and trigger operator response.

## Monitoring Paths

- **Cloud audit function (admin/master-key automation)**:
  - `auditCollectionBillReturnPercentage`
- **Mongo script (server-local/manual checks)**:
  - `backend/scripts/monitor-collection-bill-return-percentage.js`
- **Server cron wrapper (no GitHub required)**:
  - `scripts/run-return-monitor.sh`
  - optional config file: `/home/io/fin1-server/scripts/monitor.env` (template: `scripts/monitor.env.example`)
  - recommended cron: `10 5 * * * /home/io/fin1-server/scripts/run-return-monitor.sh >> /home/io/fin1-server/logs/return-monitor.log 2>&1`
  - recommended reboot catch-up: `@reboot sleep 120 && /home/io/fin1-server/scripts/run-return-monitor.sh --catchup >> /home/io/fin1-server/logs/return-monitor.log 2>&1`
  - catch-up guard: script stores last-success timestamp and skips boot catch-up if last run is recent (default max age 25h)
- **CI/scheduled job**:
  - `.github/workflows/return-percentage-contract-monitor.yml`
  - script: `scripts/monitor-return-percentage-contract.js`

## GitHub Actions Secrets

Configure these repository secrets for the monitor workflow:

- `RETURN_MONITOR_PARSE_SERVER_URL` (e.g. `https://your-host/parse` or `https://your-host`)
- `RETURN_MONITOR_PARSE_APP_ID`
- `RETURN_MONITOR_PARSE_MASTER_KEY`
- `RETURN_MONITOR_SLACK_WEBHOOK_URL` (optional, for alerts)

## Alert Message Template

Use this message for Slack/ops channels when monitor fails:

`FIN1 Return% Contract Monitor breached: missing=<missing_count>, total=<total_active>, checkedAt=<iso_time>. Run: <run_url>`

## No-Slack Email Fallback

If no Slack webhook is available, configure email alerts in `/home/io/fin1-server/scripts/monitor.env`:

- `RETURN_MONITOR_ALERT_EMAIL_TO=ops@example.com`
- `RETURN_MONITOR_ALERT_EMAIL_FROM=fin1-monitor@example.com` (optional)

Delivery options:

1. `mail` / `mailx` (if installed), or
2. direct SMTP relay via existing backend `SMTP_*` settings (no extra package required).

## Proof Of Life (Heartbeat)

- Successful monitor runs write:
  - `/home/io/fin1-server/logs/return-monitor.heartbeat`
- The heartbeat provides status + timestamp for quick verification that monitoring is alive even when no alert fires.

## Safe Forced-Breach Test

- For end-to-end alert pipeline tests without mutating production data:
  - set `RETURN_MONITOR_FORCE_BREACH=1` in `monitor.env`
  - run monitor manually once
  - verify alert path and non-zero exit
  - set `RETURN_MONITOR_FORCE_BREACH=0` immediately after test

## Incident SOP

- See: [`Documentation/RETURN_PERCENTAGE_INCIDENT_SOP.md`](./RETURN_PERCENTAGE_INCIDENT_SOP.md)

## Auth-Based Smoke Check

Use a real admin session token (not master key) to validate auth path:

`scripts/smoke-audit-return-percentage-auth.sh`

## Runbook (Breach Handling)

1. Confirm monitor values (`missing_count`, `total_active`, samples).
2. Run server-local script for detailed samples:
   - `mongosh ... backend/scripts/monitor-collection-bill-return-percentage.js`
3. Classify affected docs:
   - recoverable legacy docs -> run backfill
   - malformed docs -> archive/cleanup script
4. Validate post-fix:
   - rerun monitor (expect `missing_count=0`)
5. Record incident + root cause in release/ops notes.
