# Stabilization v1 Checklist

**Aktueller Roadmap-Fokus:** siehe `Documentation/NEXT_STEPS_ROADMAP.md` → Priorität 1 (§3 Dark-Mode Admin Portal als nächster Schritt).

Kurzcheckliste nach den umfangreichen DEV-/UI-Änderungen.

## 1) DEV-Maintenance auditierbar machen

- `devResetTradingTestData` schreibt AuditLog-Einträge für:
  - Dry-Run
  - Execute
- Pflichtdaten im Audit-Metadata:
  - `scope`, `sinceHours`
  - `counts`, `deleted`, `deletedTotal`
  - `timestamp`, `userId`

### Parse Schema-Migrationen (GoB) — nach jedem Parse-Cloud-Deploy

Siehe **`Documentation/SCHEMA_MIGRATIONS.md`**. Kurz:

- Parse Dashboard oder Cloud-Logs: Startup meldet `Schema migrations (GoB registry) ok` bzw. `partial` (siehe `main.js` ~6 s nach Boot).
- Bei Unsicherheit: Admin-Cloud **`listSchemaMigrations`** (letzte Zeilen in `SchemaMigration`) — erwartet u. a. `success: true` für `gob_investment_schema_v1` und `gob_document_schema_v1` nach erstem erfolgreichen Lauf.
- Wenn Migrationen fehlen / rot: **`updateInvestmentClassSchemaFields`** (Admin) erneut ausführen, dann erneut `listSchemaMigrations` prüfen.
- Symptom „**Permission denied for action addField on class Investment**“: Schema-Feld fehlt noch → obige Schritte, bis `feeConfigSnapshot` auf der Klasse `Investment` existiert.

## 2) Keine manuellen DB-Hotfixes für CSR-Templates

- Statt direkter Mongo-Updates: Cloud Function nutzen:
  - `backfillCSRTemplateShortcuts(dryRun=true|false)`
- Ziel: fehlende `shortcut`-Werte reproduzierbar und nachvollziehbar nachziehen.

## 3) UI-Kontrast-Risiken zentral testen

**Stand Code (2026-05):** Globale Dark-Mode-Overrides in `admin-portal/src/index.css` (Badges, Metrik-Akzente, Platzhalter-Chips, KYB-Entscheidungsflächen, graue Wells); CSR-Analytics nutzt `adminMetric*` aus `adminThemeClasses.ts`; KYB-Entscheidungsbuttons mit explizitem `isDark`-Zweig. **Manuell** weiterhin kurz prüfen (Browser, Theme-Umschalter):

- Smoke-Test-Liste für Dark Mode:
  - Benutzerliste / Benutzerdetails (inkl. Kontoauszug, rollenabhängige KPIs — siehe `FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md`, Abschnitt Benutzer-Detailseite)
  - Tickets / Compliance / Audit Logs / Konfiguration
  - CSR Templates / Hilfe & Anleitung
  - AGB & Rechtstexte (ausgeklappte Abschnitte)
- Prüfen:
  - Textkontrast (v. a. sekundäre Texte)
  - Badge-Lesbarkeit
  - Eingabefelder (Hintergrund + Text)

### §3 Routenkarte zum manuellen Dark-Mode-Smoke (60–90 Min.)

**So testen**

- Browser: Deploy-Ziel laden (Hard-Refresh: Cmd+Shift+R).
- Hell/Dunkel: Umschalten über das **Theme-Icon** in **Admin**: `admin-portal/src/components/Layout.tsx` · **CSR**: `csr-portal/components/CSRLayout.tsx` (`toggleTheme`).
- Für **Konfiguration & Risk-Ansichten** mit Admin-Login; CSR-Bereiche mit CSR-Login (`Documentation/DEV_PORTAL_LOGIN_SSOT.md`).

**Admin (gleiche SPA, Route `App.tsx`)**

| Fokus (Checkliste) | Pfad(s) |
|--------------------|---------|
| Dashboard Metriken/KPI | `/` |
| Benutzerliste / → Detail mit Kontoauszug & KPI | `/users`, `/users/:id` |
| Tickets (Liste) | `/tickets` |
| Compliance Events | `/compliance` |
| Audit Logs | `/audit` |
| Konfiguration | `/configuration` |
| Einstellungen (Formulare / 2FA-Bereiche) | `/settings` |
| System / Logs | `/system` |
| Onboarding-Funnel | `/onboarding` |
| Finance | `/finance` |
| Security Dashboard | `/security` |
| Freigaben (Approvals) | `/approvals` |
| KYB Review | `/kyb-review` |
| Rechtstexte (Accordion, Hell/Dunkel) | `/terms` |

**CSR-Portal**

| Fokus | Pfad |
|-------|------|
| Dashboard | `/csr` |
| Tickets (Liste/Queue/…) | `/csr/tickets`, `/csr/tickets/queue`, ggf. Archiv/New/Bulk nach Bedarf |
| Kundenliste / Detail | `/csr/customers`, `/csr/customers/:id` |
| KYC/KYB | `/csr/kyc`, `/csr/kyb` |
| Analytics/Trends | `/csr/analytics`, `/csr/trends` |
| Vorlagen („Templates“ / Hilfe-Anleitung) | `/csr/templates`, `/csr/faqs` |

**Pro Route kurz:**

1. Sekundärtexte und Tabellenköpfe noch lesbar?
2. Badges/Chips (Status, KPI-Bänder) differenzierbar?
3. Inputs/Selects: Hintergrund und getippter Text klar?

Auffälligkeiten als kleine Änderungen in `admin-portal/` nachziehen (`index.css`, `adminThemeClasses.ts`, betroffene Page/Components).

## 4) ENV-Änderungen korrekt ausrollen

- `backend/.env` nicht per `source` einlesen (kann shell-inkompatibel sein).
- Nach ENV-Änderungen immer:

```bash
docker compose -f docker-compose.production.yml up -d --force-recreate --no-deps parse-server
```

## 5) Release-Quickcheck

- **Admin Portal `.20` (2026-05-15):** Abnahme **Go** → `Documentation/RELEASE_ABNAHME_2026-05-15_ADMIN_PORTAL.md` §4
- `npm run build` (Admin-Portal)
- Parse Server Cloud Code geladen (Container recreated)
- UI Hard Refresh im Browser
- Kritische Flows kurz testen:
  - Legal Admin (Export/Import/Branding)
  - DEV Resets (Dry-Run + Execute)
  - CSR Template Status/Shortcut-Anzeige

## 6) Admin Summary Report — Listen-Suche (Go-Live + Monitoring + Abnahme)

**Zielbild:** production-tauglich mit dokumentierten Grenzen (kein „100 %-Search“). Siehe **`Documentation/ADMIN_LIST_SEARCH.md`**.

### Deploy / einmalig

1. **Health:** `getAdminListSearchHealth` → `healthy: true` (Text- + Prefix-Index, Sample-Blobs).
2. **Backfill** (nach Deploy / Import): `./scripts/backfill-trade-summary-flags.sh`
3. **UI:** Summary Report → Investments/Trades: Suche + Zeitraum + Filter; Button **Such-Index Status**.

Bei `healthy: false`: `ensureAdminListSearchIndexes` (Master) + Backfill erneut.

### Monitoring (Dauerbetrieb)

- **CI:** GitHub Workflow `Admin List Search Health Monitor` (wöchentlich; Secrets `RETURN_MONITOR_PARSE_*` wie Return%-Monitor).
- **Manuell:** `./scripts/check-admin-list-search-health.sh` oder Summary Report → **Such-Index Status**.

### Abnahme (Go/No-Go)

- Checkliste: **`Documentation/RELEASE_ABNAHME_SUMMARY_REPORT_SEARCH.md`** (§4 manuelle Tests, §5 Protokoll ausfüllen).

## 8) iOS — Notifications → Documents (Beleg-Inbox)

**Zielbild:** Ein CF `getUserDocumentInbox`, Client-Merge-Cache, Event-Refresh nach Settlement. Siehe `Documentation/ACCOUNT_STATEMENT_ARCHITECTURE.md`.

### Deploy

1. `./scripts/deploy-parse-cloud-to-fin1-server.sh` (inkl. `userDocumentInbox.js`)
2. iOS-App neu bauen/installieren

### Kurztest (2 Rollen)

| Rolle | Documents-Tab |
|-------|----------------|
| Investor | `investorCollectionBill` sichtbar |
| Trader | `traderCollectionBill` + `traderCreditNote` (wenn Provision) |

Kontoauszug-Beleg-Link und Documents-Tab müssen denselben Parse-`Document` öffnen.

### Abnahmeprotokoll

- **`Documentation/RELEASE_ABNAHME_IOS_DOCUMENT_INBOX.md`**

## 7) Abnahmeprotokoll verlinken

- Nach erfolgreichem Go/No-Go Test immer ein kurzes Abnahmeprotokoll ablegen und verlinken.
- Aktuelle Referenz:
  - `Documentation/RELEASE_ABNAHME_2026-05-15_ADMIN_PORTAL.md` (§5 Quickcheck Chip/Dark-Mode)
  - `Documentation/RELEASE_ABNAHME_SUMMARY_REPORT_SEARCH.md` (Summary Report Listen-Suche)
  - `Documentation/RELEASE_ABNAHME_IOS_DOCUMENT_INBOX.md` (iOS Notifications → Documents)
  - `Documentation/RELEASE_ABNAHME_2026-03-19_ADMIN_PORTAL.md`

