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

GitHub Actions (`.github/workflows/ci.yml`) includes **`parse-server-unit-tests`**: `backend/parse-server` → `npm ci` + `npm test` (Jest) on every push/PR to `main`/`master`, alongside Parse smoke/naming checks. The workflow also supports **`workflow_dispatch`** for manual CI runs from the GitHub Actions UI.

**Deploy manifest artifact:** `.github/workflows/deploy-manifest-artifact.yml` uploads `deploy-manifest-parse-cloud.json` (Git commit + optional `sourceTreeSha256` for Parse Cloud) on `workflow_dispatch`, PRs, and pushes to `main`/`master` that touch `backend/parse-server/cloud/` — see `Documentation/MODERN_DEPLOY_BEST_PRACTICES.md`.

**Parse Server Docker CI build:** `.github/workflows/parse-server-docker-build.yml` runs `docker build` with `backend/node-service.Dockerfile` (same as production compose) without pushing to a registry — catches broken production installs early.

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

**Kanone (ein physischer LAN-Server, zwei IPs):** Host `iobox` hat **WLAN `192.168.178.24`** und **Ethernet `192.168.178.20`**. **Parse/HTTPS-URLs** in Doku/Clients: **`.24`**. Beide IPs sind **derselbe Docker-Stack** — vgl. `Documentation/OPERATIONAL_DEPLOY_HOSTS.md` und `NETZWERK_KONFIGURATION.md`.

**Konfiguration:** `scripts/.env.server` (Vorlage `scripts/.env.server.example`): `FIN1_SERVER_IP` (Admin-`rsync`), optional `FIN1_PARSE_CLOUD_SSH_HOST` (Cloud-Deploy; Standard **`.24`** wenn unset). Schnellcheck: `./scripts/show-fin1-deploy-targets.sh`.

**Agent-Verhalten:** Immer **anschließend** ausführen (nicht nur „kann der Nutzer tun“), sofern Netzwerk/SSH zum Zielhost möglich ist:

1. **Admin-Portal** (Build + rsync + Verifikation):
   - `cd admin-portal && ./deploy.sh`
   - Ziel `~/fin1-server/admin/`; Host aus `FIN1_SERVER_IP` in `scripts/.env.server` (Default `.24`), siehe `admin-portal/deploy.sh`.

2. **Parse Cloud Code** (ohne `--delete` auf `utils/` versehentlich falsche Dateien zu überschreiben):
   - **`./scripts/deploy-parse-cloud-to-fin1-server.sh`** (führt Shadow-Check, `rsync` **ohne** Jest-Artefakte `__tests__`/`*.test.js`, `rm` auf `configHelper.js`, `restart parse-server` aus — Host wie oben).
   - Alternativ manuell: `./scripts/check-parse-cloud-config-helper-shadow.sh` dann `rsync`/`ssh` wie in `Documentation/OPERATIONAL_DEPLOY_HOSTS.md`.
   - **Nicht** beliebige `investment.js` nach `cloud/utils/` legen; nur `utils/investmentLimitsValidation.js` gehört nach `utils/`.
   - Requires im Cloud Code: immer `…/configHelper/index.js` (explizit), nicht nur `…/configHelper`.

3. **Parse neu laden:** ist in Schritt 2 im Skript enthalten; bei manuellem Vorgehen: `docker compose -f docker-compose.production.yml restart parse-server` auf dem **gleichen** Host wie das Cloud-`rsync`.

**iOS-App:** Kein automatisches App-Store-Deploy; Nutzer baut in Xcode. Nur Server/Admin wie oben.

Vollständigerer Überblick: `scripts/deploy-to-ubuntu.sh` (interaktiv, rsync gesamtes `backend/` ohne `--delete`).

