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

## 6) Abnahmeprotokoll verlinken

- Nach erfolgreichem Go/No-Go Test immer ein kurzes Abnahmeprotokoll ablegen und verlinken.
- Aktuelle Referenz:
  - `Documentation/RELEASE_ABNAHME_2026-05-15_ADMIN_PORTAL.md` (§5 Quickcheck Chip/Dark-Mode)
  - `Documentation/RELEASE_ABNAHME_2026-03-19_ADMIN_PORTAL.md`

