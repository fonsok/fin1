# Release Checkliste – 2026-03-24

## Scope

- Admin Panel: Neuer Finanzparameter `minInvestment` (Mindestinvestmentbetrag)
- Backend: Default-Wert auf `20,00 €` gesetzt
- Hilfe & Anleitung: FAQ-Eintrag auf dynamischen Konfigurationswert umgestellt
- Admin FAQ Editor: Sprachzuordnung DE/EN eindeutig gemacht

## Umgesetzte Aenderungen

- **Admin-Portal Konfiguration**
  - Neuer Parameter in `Konfiguration -> Finanzparameter`:
    - Key: `minInvestment`
    - Label: `Mindestinvestmentbetrag`
    - Typ: `currency`
    - Default: `20.0`
  - Datei: `admin-portal/src/pages/Configuration/ConfigurationPage.tsx`

- **Admin-Portal Freigaben (4-Augen)**
  - Anzeigename + Value-Format fuer `minInvestment` ergaenzt
  - Datei: `admin-portal/src/pages/Approvals/ApprovalsList.tsx`

- **Backend Config Defaults + Validation**
  - `limits.minInvestment` Default von `100.0` auf `20.0`
  - Validation fuer `minInvestment` ergaenzt
  - Backward-Compat-Lesen (`config.get('minInvestment')`) ergaenzt
  - Datei: `backend/parse-server/cloud/utils/configHelper/` (z. B. `defaultConfig.js`)

- **Weitere Backend Defaults**
  - `minInvestment` Fallback in `main.js` auf `20.0`
  - Mongo Init Default auf `20.0`
  - Dateien:
    - `backend/parse-server/cloud/main.js`
    - `backend/mongodb/init/00_init_admin.js`

- **FAQ dynamisch statt hardcoded**
  - FAQ-Seed auf Placeholder umgestellt:
    - `{{MIN_INVESTMENT}}`
  - Runtime Placeholder-Aufloesung in `getFAQs` implementiert:
    - `{{MIN_INVESTMENT}}` -> Live-Konfiguration (`limits.minInvestment`) als `de-DE` EUR
    - `{{APP_NAME}}` -> `legal.appName`
  - Dateien:
    - `backend/parse-server/cloud/functions/seed/faq/data.js`
    - `backend/parse-server/cloud/functions/user/faq.js`

- **FAQ Editor DE/EN Zuordnung**
  - Felder klar benannt:
    - `Frage (DE) *` -> `Antwort (DE) *`
    - `Frage (EN optional)` -> `Antwort (EN optional)`
  - Datei: `admin-portal/src/pages/FAQs/components/FAQEditor.tsx`

## Deployment Status

- Admin-Portal deployt (Build + rsync + Remote-Asset-Verifikation): **OK**
- Backend deployt nach `io@192.168.178.20`: **OK**
- Parse-Server neu gestartet, Health: **OK**
- Nginx Container force-recreate zur Aktivierung des aktuellen Admin-Bundles: **OK**

## Verifikation (Soll)

- `https://192.168.178.20/admin/faqs`
  - Editor zeigt korrekte Labels fuer DE/EN (siehe oben)
- FAQ-Eintrag:
  - Frage: `Was ist der Mindestinvestmentbetrag?`
  - Antwort enthaelt `{{MIN_INVESTMENT}}` (nicht hardcoded)
- `Konfiguration -> Finanzparameter`
  - `Mindestinvestmentbetrag` sichtbar, Default `20,00 €`
- Runtime-Test:
  - Wert im Admin-Panel aendern (z. B. 35,00)
  - FAQ neu laden -> angezeigter Betrag aktualisiert sich entsprechend

## Offene Hinweise

- Bestehende FAQ-Datensaetze mit festem Text muessen einmalig auf `{{MIN_INVESTMENT}}` migriert oder im Admin-Panel manuell angepasst werden.
- Die EN-Felder nutzen historisch die Datenfelder `questionDe`/`answerDe` (UI-seitig jetzt korrekt als EN optional beschriftet).
