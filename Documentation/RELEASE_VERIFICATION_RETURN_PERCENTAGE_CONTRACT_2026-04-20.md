# Release Verification: Return Percentage Contract (2026-04-20)

## Scope
- Canonical backend `metadata.returnPercentage` for investor collection bills
- Client consumption in investor/admin/customer-support surfaces
- Legacy backfill + malformed legacy cleanup
- Invariant and monitoring guardrails

## Verification Checklist
- [x] Backend unit tests pass (`npm test` in `backend/parse-server`)
- [x] Return contract helper tests pass (including regression fixture)
- [x] Full iOS test plan pass via CLI:
  - `xcodebuild test -scheme FIN1 -testPlan FIN1 -destination 'platform=iOS Simulator,id=56A77917-7027-4E99-88AA-9837B42EE1DB' -parallel-testing-enabled NO`
  - Result: `** TEST SUCCEEDED **`
- [x] iOS targeted failing UI tests now pass:
  - `InvestmentTradingUITests.testCompleteUISuite()`
  - `InvestmentTradingUITests.testCreateInvestment_StepByStep_ShowsInSimulator()`
  - `InvestmentTradingUITests.testInvestmentUISuite()`
- [x] Parse Cloud deployed to `fin1-server` (`scripts/deploy-to-ubuntu.sh 192.168.178.20 io`)
- [x] `parse-server` restarted and healthy (`docker compose ... restart parse-server`, health = healthy)
- [x] Historical backfill executed for missing return percentage where recoverable
- [x] Malformed legacy collection bills archived out of active scope
- [x] Hard release gate (Go/No-Go): `missingReturnPercentageCount` MUST equal `0` before production release
- [x] Auth smoke check (real admin session token) passes for `auditCollectionBillReturnPercentage`
- [x] Redundant alert fallback available (file + syslog + SMTP path)
- [x] Weekly reconciliation job defined for drift checks
- [x] DB boundary validator applied in production (`backend/scripts/apply-document-return-percentage-validator.js`)
- [x] Alert recipient configured in production monitor env (`RETURN_MONITOR_ALERT_EMAIL_TO`)

## Notes
- A first parallelized `xcodebuild test` run hit a simulator runner launch denial (`ra.FIN1UITests.xctrunner`) and was stopped.
- After simulator reset and non-parallel run, the full test plan completed successfully.

## Monitoring
- Daily/periodic query script:
  - `backend/scripts/monitor-collection-bill-return-percentage.js`
- Cloud audit endpoint (admin-only):
  - `auditCollectionBillReturnPercentage`

## Expected Ongoing Behavior
- New active collection bills always include `metadata.returnPercentage`
- Clients never compute return percentage locally
- Missing canonical values surface as `pending` and are visible to monitoring

## Release Gate Policy
- Block release if monitor/audit reports `missingReturnPercentageCount > 0`.
- Block release if auth-based smoke test fails:
  - `scripts/smoke-audit-return-percentage-auth.sh`

## Auth Smoke Evidence
- Date: 2026-04-20
- Result: `Smoke test succeeded`
- Endpoint path: `auditCollectionBillReturnPercentage`
- Auth mode: real admin session token (no master key)
