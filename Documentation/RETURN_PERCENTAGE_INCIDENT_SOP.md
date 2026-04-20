# Return% Incident SOP

## Trigger

- Monitor reports `missingReturnPercentageCount > MONITOR_THRESHOLD`
- Or monitor fails unexpectedly for more than 25h (missing heartbeat cadence)

## Owner & SLA

- Primary owner: Backend on-call / Release owner
- Initial triage: within 60 minutes
- Mitigation target: same business day

## Triage Steps

1. Confirm alert details (`missing`, `total`, `checkedAt`).
2. Re-run monitor on server:
   - `/home/io/fin1-server/scripts/run-return-monitor.sh`
3. Inspect monitor log:
   - `tail -n 200 /home/io/fin1-server/logs/return-monitor.log`
4. Run detailed DB check:
   - `backend/scripts/monitor-collection-bill-return-percentage.js`

## Mitigation

1. Recoverable legacy docs:
   - run backfill script for `metadata.returnPercentage`
2. Malformed/invalid legacy docs:
   - run cleanup/archive script to exclude from active scope
3. Re-run monitor:
   - require `missingReturnPercentageCount=0`

## Validation & Closure

1. Verify UI behavior remains correct (`pending` only when canonical value unavailable).
2. Attach evidence (monitor output + post-fix output) to release/incident notes.
3. Capture root cause and prevention action (test, invariant, or migration improvement).
