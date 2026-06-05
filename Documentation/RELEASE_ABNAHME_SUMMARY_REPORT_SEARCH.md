# Release-Abnahme — Summary Report Listen-Suche

**Ziel:** Go-Live für Admin Summary Report (Investments/Trades) mit MongoDB-Textsuche, Filter, Zeitraum und Ops-Monitoring — ohne „100 %“-Anspruch, mit **Go-Live + Monitoring + Abnahme**.

**Referenzen**

- Technik: `Documentation/ADMIN_LIST_SEARCH.md`
- Stabilization: `Documentation/STABILIZATION_V1_CHECKLIST.md` §6
- Monitoring: `.github/workflows/admin-list-search-health-monitor.yml`, `scripts/monitor-admin-list-search-health.js`

---

## 1) Vor Deploy (lokal / CI)

| Check | Erwartung |
|-------|-----------|
| Parse Cloud Tests (Summary Report / `adminListSearch`) | ✅ Pass |
| `admin-portal` `npm run build` | ✅ Pass |
| Optional: `node scripts/monitor-admin-list-search-health.js` gegen Ziel-Parse (mit Master-Env) | `healthy=true` |

---

## 2) Deploy (.20 oder Prod-Ziel)

```bash
./scripts/deploy-parse-cloud-to-fin1-server.sh
# Schema-Migration admin_list_search_v1 läuft beim Parse-Start (siehe SCHEMA_MIGRATIONS.md)

./scripts/backfill-trade-summary-flags.sh   # einmalig nach Deploy / Import

./admin-portal/deploy.sh
```

Browser: **Hard Refresh** (Cmd+Shift+R).

---

## 3) Ops / Monitoring

| Kanal | Aktion |
|-------|--------|
| **GitHub Actions** | Workflow `Admin List Search Health Monitor` (wöchentlich + `workflow_dispatch`); Secrets wie Return%-Monitor (`RETURN_MONITOR_PARSE_*`) |
| **Shell** | `./scripts/check-admin-list-search-health.sh` |
| **Admin UI** | Summary Report → **Such-Index Status** (Hover = Kurzinfo, Klick = Detail-Dialog) |

Bei `healthy: false`: `ensureAdminListSearchIndexes` (Master) + Backfill erneut (siehe `ADMIN_LIST_SEARCH.md`).

---

## 4) Manuelle Abnahme (Go/No-Go)

Als **Admin** einloggen (`Documentation/DEV_PORTAL_LOGIN_SSOT.md`).

### A) Such-Index Status

- [ ] Summary Report → **Such-Index Status** → Dialog: **OK (healthy)**
- [ ] Investment + Trade: Text-Index **ja**, Prefix-Index **ja**
- [ ] Beispiel-`adminSearchBlob`: mindestens **ja** für eine Collection (idealerweise beide)

### B) Tab Investments

- [ ] Live-Suche (z. B. Investor-Name, `INV-…`) liefert erwartete Treffer
- [ ] Filter (Status, Return-Band, …) + **Zurücksetzen**
- [ ] **Zeitraum** (Preset + Von/Bis) schränkt Liste ein
- [ ] Pagination / Sortierung ohne Fehler

### C) Tab Trades

- [ ] Suche (Trade-Nr., Symbol, Trader) + Filter + Zeitraum wie bei Investments
- [ ] Pool-Filter (`hasPoolParticipation`) plausibel
- [ ] Expand/Detail-Zeilen laden (keine 500er in Network)

### D) Regression Overview

- [ ] Tab **Übersicht**: KPI-Karte + Zeitraum-Filter aktualisiert Zahlen

**Go** wenn A–D ohne Blocker; **No-Go** bei dauerhaft `healthy: false`, leeren Suchergebnissen trotz bekannter Daten, oder Timeout-Fehlern in Listen-APIs.

---

## 5) Abnahmeprotokoll (ausfüllen)

| Feld | Wert |
|------|------|
| Datum | |
| Umgebung | z. B. `192.168.178.20` |
| Git-Ref (Admin + Cloud) | |
| Health (UI oder Script) | healthy: true / false |
| Go / No-Go | |
| Tester | |
| Anmerkungen | |

Nach **Go**: Eintrag in §7 Stabilization-Checkliste verlinken (diese Datei).
