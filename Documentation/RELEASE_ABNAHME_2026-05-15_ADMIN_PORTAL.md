# Release-Abnahme Admin Portal (2026-05-15)

Stabilization v1 — **§5 Release-Quickcheck** nach Chip-SSOT, Compliance/Audit-Typ-Farben, Dark-Mode §3.

## Referenzen

- Checkliste: `Documentation/STABILIZATION_V1_CHECKLIST.md` §5
- Vorherige Abnahme: `Documentation/RELEASE_ABNAHME_2026-03-19_ADMIN_PORTAL.md`
- Git `main` zum Abnahme-Start der Checkliste: `b2650e4`; **aktueller Deploy** gebaut aus `main` `@c1f90ba` (Chip slate + Docs; iOS-File-Size-CI ist rein repo-seitig)

---

## 1) Automatisiert (lokal, 2026-05-15)

| Check | Ergebnis |
|-------|----------|
| `admin-portal` ESLint | ✅ Pass |
| `admin-portal` Vitest (252 Tests) | ✅ Pass |
| `admin-portal` `npm run build` (tsc + vite) | ✅ Pass |
| Parse Cloud shadow `configHelper.js` | ✅ OK |
| Parse Cloud naming conventions | ✅ OK (keine geänderten Cloud-Dateien im Diff) |

**CI:** `admin-portal`-Job ✅ inkl. ESLint slate (`b2650e4`). **iOS** `build-test-lint` → **Check File Sizes** mit `./scripts/check-file-sizes.sh --mode baseline` (Layer 1, auf `main` ab `13bf19c`).

---

## 2) Deployment-Stand (.20)

| Artefakt | Stand |
|----------|--------|
| Admin SPA auf `192.168.178.20` | `index-f899-fZR.js` + `index-CF4kClKH.css` (Deploy `./admin-portal/deploy.sh`, 2026-05-15; `nginx` danach recreated) |
| Gebaut gegen | Repo `main` `@c1f90ba` lokal (`npm run build`) |
| Enthält | Chip-SSOT, Audit-/Compliance-Typ-Chips, §3 QuickActions/Kontoauszug/Security, ESLint `slate-*` Chip-Tokens |

**Browser:** Hard Refresh (Cmd+Shift+R) vor manuellen Tests.

**Parse Cloud:** Bei Backend-Änderungen seit letztem Deploy:

```bash
./scripts/deploy-parse-cloud-to-fin1-server.sh
# ggf. parse-server Container recreate (siehe STABILIZATION §4)
```

---

## 3) Manuelle Kritische Flows (Go/No-Go)

Als **Admin** einloggen (DEV-Accounts: `Documentation/DEV_PORTAL_LOGIN_SSOT.md`).

### A) Legal Admin — Export / Import / Branding

**Route:** `/terms` (AGB & Rechtstexte)

| # | Schritt | OK |
|---|---------|-----|
| A1 | **Export** vollständiges Backup (JSON-Download) | ☑ |
| A2 | **Export aktiv** (gefiltert) lädt Datei | ☑ |
| A3 | **Import** Dry-Run → Vorschau-Zahlen plausibel → Abbruch | ☑ |
| A4 | **Branding** laden/anzeigen (falls sichtbar in UI) | ☑ |
| A5 | Dark Mode: ausgeklappte Abschnitte lesbar | ☑ |

### B) DEV Reset — Dry-Run + Execute

**Route:** `/system` → Bereich **DEV Reset Trading-Testdaten**

| # | Schritt | OK |
|---|---------|-----|
| B1 | **Dry-Run** → Confirm-Dialog mit Counts, **nicht** ausführen | ☑ |
| B2 | Optional Execute nur in **DEV/Test** mit Backup-Bewusstsein | ☑ |
| B3 | **Audit-Logs** (`/audit`): Einträge `logType=action` nach Execute, Metadata mit `scope` / counts | ☑ |

### C) CSR Templates — Status / Shortcut-Chips

**Route:** `/templates` (CSR-Vorlagen)

| # | Schritt | OK |
|---|---------|-----|
| C1 | Liste: **Shortcut-Chips** farblich unterschiedlich (nicht alle gleich) | ☑ |
| C2 | **Backfill Shortcuts** Dry-Run → Vorschau → optional Apply | ☑ |
| C3 | Editor: Platzhalter-Chips lesbar (hell/dunkel) | ☑ |

### D) Regression Smoke (empfohlen, kurz)

| Route | Prüfpunkt | OK |
|-------|-----------|-----|
| `/audit` | Typ-Chips unterschiedlich (`data_access`, `action`, …) | ☑ |
| `/compliance` | Typ: blau/gelb/grün/rot für Trading-Quartett | ☑ |
| `/csr` | Schnellaktionen-Kacheln im Dark Mode nicht blass/grau | ☑ |
| `/users` → Detail | Kontoauszug Eintrags-Chips lesbar | ☑ |

---

## 4) Go / No-Go

| Entscheidung | Datum | Verantwortlich |
|--------------|-------|----------------|
| ☑ Go | 2026-05-15 | ra |
| ☐ No-Go (Blocker: _______________) | | |

---

## 5) Enthaltene Änderungen (seit 2026-03-19 Abnahme)

- Portal Chip SSOT (`chipVariants.ts`, Badge, Tickets)
- Audit-Log Typ-Spalte: eigene Farben pro `logType`
- Compliance: Typ + Schweregrad + iOS camelCase (`orderPlaced`, `riskCheck`, …)
- §3 Dark Mode: QuickActions, Kontoauszug, Security Severity, Finance-Alerts
- ESLint CI-Fix: `gray-*` → `slate-*` in Chip-Light-Paletten
