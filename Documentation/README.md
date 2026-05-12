# FIN1 Dokumentation – Start hier

Die Menge an `.md` Dateien in diesem Workspace ist sehr groß. Damit es nicht verwirrend wird, gibt es einen **klaren Einstieg** und eine klare Regel, welche Dateien “aktuell” sind.

## ⭐ Startpunkte

- **Repo-Startpunkt (rollenorientiert)**: `START_HERE.md`
- **Kuratierte Gesamtdoku (“Current”)**: `Documentation/FIN1_APP_DOCS/00_INDEX.md`
- **Snapshots/Tags Index**: `Documentation/SNAPSHOTS_INDEX.md`
- **Deployment / rsync (kein `--delete` auf dem Server-Backend)**: `Documentation/DEPLOYMENT_RSYNC_SICHERHEIT.md`
- **Deploy-Host-Klarheit (iobox, zwei IPs, Env-Variablen)**: `Documentation/OPERATIONAL_DEPLOY_HOSTS.md`
- **Company-KYB (Firmen-Onboarding, Plan):** `Documentation/COMPANY_KYB_ONBOARDING.md`
- **Return%-Contract Monitoring & Alerting:** `Documentation/RETURN_PERCENTAGE_MONITORING_AND_ALERTING.md`
- **Return%-Incident SOP:** `Documentation/RETURN_PERCENTAGE_INCIDENT_SOP.md`
- **Return%-Release Verification:** `Documentation/RELEASE_VERIFICATION_RETURN_PERCENTAGE_CONTRACT_2026-04-20.md`

## ✅ Regel: “Current” ohne Versionssuffix

- “Current” sind die Dateien **ohne** Versionssuffix (z.B. `START_HERE.md`, `FIN1_PROJECT_STATUS.md`).
- Historie/“Snapshots” laufen über **Git** (Commits + optional Tags).

## 📚 Kuratierte FIN1 App-Dokumentation (Zielgruppen-orientiert)

Wenn du eine **konsistente, aktuelle** Gesamtdoku suchst (Stakeholder → Dev → QA/Ops → User), starte hier:

- `Documentation/FIN1_APP_DOCS/00_INDEX.md`
- **iOS-Client ↔ Parse REST / Swift 6 (DTOs, Sendable):** maßgeblich `Documentation/FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md` (Abschnitt 1, Unterpunkt Swift 6 / Parse REST).

## 📚 Weitere Doku-Bereiche (nicht immer aktuell)

- `Documentation/` enthält viele Notes/Analysen/Reviews.
- `FIN1/Documentation/` enthält feature-nahe Notes/Reviews + Archive.

Wenn etwas widerspricht: **Code/Config schlägt Textdoku** (siehe `Documentation/FIN1_APP_DOCS/00_INDEX.md`).

