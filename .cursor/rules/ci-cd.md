---
alwaysApply: true
---

# Local Development & Code Quality Rules

This rule file incorporates local development requirements. The `.github/workflows/ci.yml` file is a reference configuration for when CI is available, but all checks must pass **locally** before committing.

**Note**: These rules apply regardless of GitHub connectivity. All validations are performed locally.

## Parse Cloud Code (`backend/parse-server/cloud/`) — feste Regeln

Diese Punkte vermeiden produktive Fehler (Admin-Konfiguration, FAQ-Platzhalter, „… is not a function“):

- **`require` immer explizit:** `…/configHelper/index.js` — **niemals** nur `…/configHelper` (Legacy-Datei `utils/configHelper.js` auf dem Server würde sonst das Paket überschatten).
- **Keine Datei** `cloud/utils/configHelper.js` im Repo oder auf dem Host anlegen/wiederherstellen; vor Commit/Deploy: `./scripts/check-parse-cloud-config-helper-shadow.sh`.
- **Betriebsdoku:** `Documentation/FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md` **§ 8.2.1** (Symptome, `rm`, Verifikation).

## Local Build and Test Requirements

All code changes must pass these local checks (matching what would run in CI if available):

1. **SwiftFormat Check**: `swiftformat . --lint`
   - Code must be properly formatted
   - Run `swiftformat .` locally before committing

2. **SwiftLint Check**: `swiftlint` (non-strict in CI)
   - Error-severity violations fail CI; warnings (including most custom rules) are reported but do not fail CI. Use `swiftlint --strict` locally for a zero-warning check. See `swiftlint.md`.
   - Do not introduce new error-severity violations; reduce warnings in code you touch when practical.
   - Incremental pass: `./scripts/swiftlint-changed.sh` (lint only Swift files changed vs `origin/main`).
   - Weekly strict run: `.github/workflows/swiftlint-strict-weekly.yml` (also trigger manually via **Actions**).

3. **Build Test**: Builds for iOS Simulator
   - CI runs tests via **`scripts/run-ios-tests.sh`**, which picks the **first available iPhone** simulator by UDID (avoids `name=iPhone …` resolving to **OS:latest** with no matching runtime).
   - For a one-off build: `xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,id=<UDID>' build` (get `<UDID>` from Xcode or `xcrun simctl list`).
   - **MANDATORY**: If build fails, repeat builds until all errors are fixed and "BUILD SUCCEEDED" is achieved
   - Never commit code that doesn't build successfully

4. **Unit Tests**: All tests must pass
   - Prefer CI parity: `./scripts/run-ios-tests.sh` (or pass extra `xcodebuild` test arguments at the end).
   - Use test plan: `FIN1/FIN1.xctestplan`

5. **Danger (Optional)**: For projects with CI/CD, Danger can run automated code review checks
   - Dangerfile.swift contains review rules
   - **Not required for local development**

### Environment

- **Xcode**: `/Applications/Xcode.app`
- **Tools**: SwiftLint, SwiftFormat installed via Homebrew (or locally)
- **Note**: Danger is optional and only required if using CI/CD with GitHub

### Pre-Commit Requirements

Before committing, ensure:
1. ✅ `swiftformat . --lint` passes
2. ✅ `swiftlint` passes (exit 0; use `swiftlint --strict` if you are clearing the warning backlog)
3. ✅ Build succeeds - must see "BUILD SUCCEEDED" (retry until all errors fixed)
4. ✅ Tests pass locally

### Responsive Design Compliance

Local validation (see also `responsive-design.md` rule file):
- Run `scripts/check-responsive-design.sh` to validate ResponsiveDesign usage
- SwiftLint automatically enforces ResponsiveDesign rules (see `.swiftlint.yml`)
- Verify build and tests pass with ResponsiveDesign-compliant code

**Note**: `.github/workflows/responsive-design-compliance.yml` is a reference for CI setup, but validation happens locally.

## Local Development Commands

Reference these commands from `.cursorrules`:

- **Lint format**: `swiftformat . --lint`
- **SwiftLint**: `swiftlint` (stricter: `swiftlint --strict`)
- **Format code**: `swiftformat .`
- **Build (sim)**: use a concrete simulator `id=` from `xcrun simctl list devices available`, or Xcode UI
- **Test (sim)**: `./scripts/run-ios-tests.sh`

## Code Quality Requirements

All code changes must:
1. Pass all local checks (formatting, linting, build, tests)
2. Introduce no new SwiftLint error-severity issues; avoid adding warnings in files you change when practical
3. Follow MVVM architecture patterns (see `.cursorrules`)
4. Use ResponsiveDesign system (see `responsive-design.md`)
5. Pass all tests before committing

**Note**: If you have CI/CD set up later, these same checks will run automatically.

## Build Retry Policy

**CRITICAL**: When a build fails or before committing:
1. Analyze all build errors and warnings
2. Fix all compilation errors
3. Address all warnings (treat as errors)
4. Re-run the build with a concrete simulator **id** (see `xcrun simctl list devices available`)
5. If build still fails, repeat steps 1-4 until you see **"BUILD SUCCEEDED"**
6. **Before committing**: Build must succeed - never commit code that doesn't build

**Rationale**: You can make iterative changes during development, but always verify the build succeeds:
- Before committing code
- When you intentionally run a build to check status
- Before moving to a different task/feature

**Never commit code that doesn't build successfully.**

## Failure Prevention

When making code changes:
- Make iterative changes as needed during development
- **Before committing**: Verify build succeeds - if it fails, fix all errors and rebuild until "BUILD SUCCEEDED"
- Run linting/formatting checks before committing
- Ensure tests pass before committing
- Check for any new SwiftLint violations
- Follow all architectural patterns defined in `.cursorrules`
- All validation happens **locally** - no external services required

## FIN1-Server Deploy (Pflicht nach relevanten Änderungen)

**Wann:** Nach Änderungen an **`backend/parse-server/cloud/`** (Cloud Code, `main.js`, `utils/`), **`admin-portal/`** (gebündeltes Admin-UI), oder wenn der Nutzer ausdrücklich Deploy wünscht.

**Agent-Verhalten:** Immer **anschließend** ausführen (nicht nur „kann der Nutzer tun“), sofern Netzwerk/SSH zum Zielhost möglich ist:

1. **Admin-Portal** (Build + rsync + Verifikation):
   - `cd admin-portal && ./deploy.sh`
   - Erwartung: Standard-Host `io@192.168.178.20`, Ziel `~/fin1-server/admin/` (siehe Skript / `scripts/.env.server`).

2. **Parse Cloud Code** (ohne `--delete` auf `utils/` versehentlich falsche Dateien zu überschreiben):
   - Vor Deploy: `./scripts/check-parse-cloud-config-helper-shadow.sh` (scheitert, falls `cloud/utils/configHelper.js` existiert — würde `configHelper/` überschatten).
   - `rsync -avz backend/parse-server/cloud/ io@192.168.178.20:~/fin1-server/backend/parse-server/cloud/`
   - Auf dem Server ggf. `rm -f …/cloud/utils/configHelper.js` (macht `deploy-to-ubuntu.sh` automatisch nach rsync).
   - **Nicht** beliebige `investment.js` nach `cloud/utils/` legen; nur `utils/investmentLimitsValidation.js` gehört nach `utils/`.
   - Requires im Cloud Code: immer `…/configHelper/index.js` (explizit), nicht nur `…/configHelper`.

3. **Parse neu laden:** Auf dem Server z. B.  
   `ssh io@192.168.178.20 'cd ~/fin1-server && docker compose -f docker-compose.production.yml restart parse-server'`  
   (Service-Name bei Abweichung anpassen.)

**iOS-App:** Kein automatisches App-Store-Deploy; Nutzer baut in Xcode. Nur Server/Admin wie oben.

Vollständigerer Überblick: `scripts/deploy-to-ubuntu.sh` (interaktiv, rsync gesamtes `backend/` ohne `--delete`).

