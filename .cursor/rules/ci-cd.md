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

**Parse Server Docker CI build:** `.github/workflows/parse-server-docker-build.yml` builds with Buildx + GHA cache (same Dockerfile as production compose). On **push/workflow_dispatch** to `main`/`master` (not PRs), it also **pushes** to **GHCR** `ghcr.io/<lowercase-owner>/fin1-parse-server` (`:<sha>` and `:<branch>`). Host pull: merge `docker-compose.parse-server-ghcr.yml` + `FIN1_PARSE_SERVER_IMAGE` (runbook `06A` §8.1). Local build only: `./scripts/ci-build-parse-server-docker.sh`. **Podman later:** OCI pull works the same (`Documentation/MODERN_DEPLOY_BEST_PRACTICES.md` §10).

**Production Compose config:** `.github/workflows/compose-production-validate.yml` runs `docker compose … config -q` with committed CI stubs (`scripts/ci/`) so broken `docker-compose.production.yml` or missing interpolation vars fail before deploy.

All code changes must pass these local checks (matching what would run in CI if available):

1. **SwiftFormat Check** (same roots as `.github/workflows/ci.yml`; do **not** use `swiftformat .` — it lints `build/` and other noise):
   - `swiftformat FIN1 FIN1Tests FIN1UITests FIN1InvestorTests FIN1CoreRegressionTests --lint`
   - Apply: `swiftformat FIN1 FIN1Tests FIN1UITests FIN1InvestorTests FIN1CoreRegressionTests`

2. **SwiftLint Check**: `swiftlint` (non-strict in CI)
   - Error-severity violations fail CI; warnings (including most custom rules) are reported but do not fail CI. Use `swiftlint --strict` locally for a zero-warning check. See `swiftlint.md`.
   - Do not introduce new error-severity violations; reduce warnings in code you touch when practical.
   - Incremental pass: `./scripts/swiftlint-changed.sh` (lint only Swift files changed vs `origin/main`).
   - Weekly strict run: `.github/workflows/swiftlint-strict-weekly.yml` (also trigger manually via **Actions**).

3. **Build Test**: Builds for iOS Simulator
   - CI runs tests via **`scripts/run-ios-tests.sh`**; GitHub sets **`IOS_TEST_DESTINATION`** (see `.github/workflows/ci.yml`). Locally, override if needed: `IOS_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=18.6' ./scripts/run-ios-tests.sh`
   - One-off build: `xcodebuild … -destination 'platform=iOS Simulator,name=iPhone 16,OS=<your-runtime>' build` or `make build` / VS Code tasks (see `Makefile`, `.vscode/tasks.json`).
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
1. ✅ `swiftformat FIN1 FIN1Tests FIN1UITests FIN1InvestorTests FIN1CoreRegressionTests --lint` passes
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

- **Lint format**: `swiftformat FIN1 FIN1Tests FIN1UITests FIN1InvestorTests FIN1CoreRegressionTests --lint`
- **SwiftLint**: `swiftlint` (stricter: `swiftlint --strict`)
- **Format code**: `swiftformat FIN1 FIN1Tests FIN1UITests FIN1InvestorTests FIN1CoreRegressionTests`
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

## PR before merge (Policy C)

Short checklist for merge-ready work (humans + agents). Full German wording: **PR Guardrails** / **Policy C** in `Documentation/ENGINEERING_GUIDE.md`.

1. **Scope:** One PR = one coherent theme (Parse Cloud vs iOS vs CI/workflows vs admin-portal vs documentation).
2. **Quality:** Run checks that match the diff (iOS build/tests per `ci.yml`; Parse Cloud: `npm test` under `backend/parse-server`; admin-portal: `npm run lint`, `npm run test:run`, `npm run build`).
3. **Description:** State purpose, rollback note, and deploy impact (`./scripts/deploy-parse-cloud-to-fin1-server.sh`, `./admin-portal/deploy.sh`) when server artifacts change. For **admin-portal** source changes, assume **deploy is required** (see FIN1-Server Deploy below).
4. **Merge hygiene:** Green CI; resolve conflicts on the feature branch; do not rewrite `main` / `origin/main` history.
5. **Routine:** Large stabilization waves on `main` are an **exception** after first green; default back to small PRs.

**Squash vs two commits:** Do not retroactively squash work already on `origin/main`. Intentionally kept two-commit pairs on shared `main` remain valid; re-applying that debate to old SHAs adds risk, not clarity.

## Repo hygiene (admin bundles)

Do not commit **`admin-portal/dist/`** or repo-root **`admin/`** hashed bundles. CI runs **`scripts/check-no-tracked-admin-spa-artifacts.sh`** (see `.github/workflows/ci.yml`, job `parse-smoke-local-mock`). Deploy built assets with **`admin-portal/deploy.sh`** / server sync only.

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

**Wann:** Nach Änderungen an **`backend/parse-server/cloud/`** (Cloud Code, `main.js`, `utils/`). Nach **jeder** Änderung am **`admin-portal/`**-Quellbaum (inkl. ESLint-Regeln, Refactors ohne sichtbare UI-Änderung): **immer** `./admin-portal/deploy.sh` ausführen — nicht nur auf ausdrückliche Nutzeranfrage. Zusätzlich bei ausdrücklichem Deploy-Wunsch für andere Bereiche.

**Hinweis (Team-Policy):** Admin-Portal-Deploy nach Portal-Arbeit ist **standardmäßig Pflicht**, damit der LAN-Host (`~/fin1-server/admin/`) dem committed Stand entspricht.

**Kanone (ein physischer LAN-Server, zwei IPs):** Host `iobox` hat **WLAN `192.168.178.24`** und **Ethernet `192.168.178.20`**. **Parse/HTTPS-URLs** in Doku/Clients: **`.24`**. Beide IPs sind **derselbe Docker-Stack** — vgl. `Documentation/OPERATIONAL_DEPLOY_HOSTS.md` und `NETZWERK_KONFIGURATION.md`.

**Konfiguration:** `scripts/.env.server` (Vorlage `scripts/.env.server.example`): `FIN1_SERVER_IP` (Admin-`rsync`), optional `FIN1_PARSE_CLOUD_SSH_HOST` (Cloud-Deploy; Standard **`.24`** wenn unset). Schnellcheck: `./scripts/show-fin1-deploy-targets.sh`.

**Agent-Verhalten:** Immer **anschließend** ausführen (nicht nur „kann der Nutzer tun“), sofern Netzwerk/SSH zum Zielhost möglich ist. **Admin-Portal:** Nach jedem Commit/Push, der `admin-portal/` betrifft, **`./admin-portal/deploy.sh`** vom Repo-Root ausführen (baut, rsync’t, nginx-Refresh) — auch bei rein internen Änderungen.

1. **Admin-Portal** (Build + rsync + Verifikation) — **nach jeder `admin-portal/`-Änderung:**
   - `./admin-portal/deploy.sh` (vom Repo-Root; alternativ `cd admin-portal && ./deploy.sh`)
   - Ziel `~/fin1-server/admin/`; Host aus `FIN1_SERVER_IP` in `scripts/.env.server` (Default `.24`), siehe `admin-portal/deploy.sh`.

2. **Parse Cloud Code** (ohne `--delete` auf `utils/` versehentlich falsche Dateien zu überschreiben):
   - **`./scripts/deploy-parse-cloud-to-fin1-server.sh`** (führt Shadow-Check, `rsync` **ohne** Jest-Artefakte `__tests__`/`*.test.js`, `rm` auf `configHelper.js`, `restart parse-server` aus — Host wie oben).
   - Alternativ manuell: `./scripts/check-parse-cloud-config-helper-shadow.sh` dann `rsync`/`ssh` wie in `Documentation/OPERATIONAL_DEPLOY_HOSTS.md`.
   - **Nicht** beliebige `investment.js` nach `cloud/utils/` legen; nur `utils/investmentLimitsValidation.js` gehört nach `utils/`.
   - Requires im Cloud Code: immer `…/configHelper/index.js` (explizit), nicht nur `…/configHelper`.

3. **Parse neu laden:** ist in Schritt 2 im Skript enthalten; bei manuellem Vorgehen: `docker compose -f docker-compose.production.yml restart parse-server` auf dem **gleichen** Host wie das Cloud-`rsync`.

**iOS-App:** Kein automatisches App-Store-Deploy; Nutzer baut in Xcode. Nur Server/Admin wie oben.

Vollständigerer Überblick: `scripts/deploy-to-ubuntu.sh` (interaktiv, rsync gesamtes `backend/` ohne `--delete`).

