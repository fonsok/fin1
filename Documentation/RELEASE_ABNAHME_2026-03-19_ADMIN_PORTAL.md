# Release-Abnahme Admin Portal (2026-03-19)

## Status

- Abnahme erfolgreich abgeschlossen.
- Go/No-Go Checkliste wurde vollständig erfolgreich durchlaufen.
- Änderungen sind auf dem Zielsystem deployed.

## Enthaltene Änderungen

- Refactoring großer Admin-Portal-Seiten ohne Verhaltensänderung:
  - `admin-portal/src/pages/Templates/TemplatesPage.tsx`
  - `admin-portal/src/pages/Terms/TermsPage.tsx`
  - `admin-portal/src/pages/Configuration/ConfigurationPage.tsx`
  - `admin-portal/src/pages/Users/UserDetail.tsx`
- Neue Anlage-Funktion für E-Mail-Vorlagen (Modal-Flow).
- Fix für Löschen neu erstellter Templates (ID-Normalisierung im API-Layer).
- Sicherheits-Guardrails für Benutzerstatus:
  - keine Selbstsperrung für Admins
  - Schutz vor Sperrung des letzten aktiven Admins

## Verifikation

- Frontend-Build erfolgreich (`npm run build`).
- Lint-Checks ohne neue Fehler.
- Funktionale Checks erfolgreich:
  - AGB & Rechtstexte (Export/Import/Filter/Branding/DEV-Dry-Run)
  - CSR Templates (E-Mail-Vorlage erstellen/bearbeiten)
  - Benutzer / User Detail (Actions/Modal/Anzeige)
  - Konfiguration (Edit-Flow inkl. Cross-Limit-Validierung)

## Deployment

- Admin-Portal erfolgreich deployed auf `192.168.178.20`.
- Parse-Server für Backend-Guardrails neu gestartet (Container Recreate).

## Nachtrag (Backend Refactor + Smoke, 2026-03-19)

- Zusätzliches Backend-Refactoring ohne Verhaltensänderung deployed:
  - `backend/parse-server/cloud/utils/permissions.js` → modularisiert nach `utils/permissions/`
  - `backend/parse-server/cloud/utils/accountingHelper.js` → modularisiert nach `utils/accountingHelper/`
  - `backend/parse-server/cloud/functions/admin/fourEyes.js` → modularisiert nach `functions/admin/fourEyes/`
- Parse-Container nach Upload neu gestartet; Health-Status geprüft (`parse-server`, `mongodb`, `redis`, `nginx` jeweils healthy).
- Smoke-Checks erfolgreich:
  - Parse Health Endpoint (`/health`) liefert healthy.
  - `getPendingApprovals` liefert mit gültigem Session-Token reguläre Result-Daten (Auth- und Laufzeitpfad verifiziert).

## Rest-Risiken / Hinweise

- Keine offenen Blocker aus der Abnahme.
- Empfohlen: bei nächstem Wartungsfenster ergänzende UI-E2E-Smoke-Tests für die kritischen Admin-Flows.

## Nachtrag (Dokumentation Benutzer-Detail, 2026-04-04)

Die implementierte **Benutzer-Detailseite** (`UserDetail.tsx`, `getUserDetails` inkl. Kontoauszug aus `AccountStatement`, rollenabhängige Trading-/Investment-Bereiche, optionaler Wallet-Saldo als „Kontostand“) ist in **`FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md`** (Abschnitt **Benutzer-Detailseite**) und in **`.cursor/rules/admin-portal.md`** beschrieben — ergänzend zu dieser Release-Notiz.
