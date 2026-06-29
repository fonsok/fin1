# Release-Abnahme — Paired Buy (Backend E2E)

**Zweck:** Manueller Regression-Check nach Änderungen an `executePairedBuy`, Order-Idempotenz oder Settlement — **nicht** als GitHub-Actions-Job (Homelab-Parse hinter LAN).

**Referenz:** [`PAIRED_BUY_SELL_INVESTOR_INVARIANTS.md`](PAIRED_BUY_SELL_INVESTOR_INVARIANTS.md), [`FIN1_APP_DOCS/05_TEST_QUALITAET.md`](FIN1_APP_DOCS/05_TEST_QUALITAET.md)

**Datum:** ___________  
**Tester:** ___________  
**Umgebung:** ☐ Staging (iobox) ☐ Lokal mit Tunnel

---

## Wann ausführen?

- [ ] PR/Deploy berührt `backend/parse-server/cloud/functions/tradingPairedBuy*.js`
- [ ] PR/Deploy berührt `orderTriggerBeforeSave` / `orderNumber`
- [ ] Release mit Trader-Buy-Flow (iOS `BuyOrderPlacementService`)
- [ ] Incident-Triage nach Duplicate-Order oder ABORTED-Stuck

**Parallel in CI (ohne Homelab):** Jest `tradingPairedBuyExecution.test.js` — ersetzt diesen Check **nicht** vollständig (kein finalize + `getOpenTrades`).

---

## Voraussetzungen

| Punkt | Details |
|-------|---------|
| **Parse** | Cloud deployed auf iobox — [`OPERATIONAL_DEPLOY_HOSTS.md`](OPERATIONAL_DEPLOY_HOSTS.md) |
| **Tools** | `curl`, `python3`, `bash` |
| **Test-Trader** | Standard: `trader2@test.com` / `TestPassword123!` (verschmutzt `trader1` nicht) |
| **Application ID** | `fin1-app-id` |

### Option A — Direkt im LAN (Mac im gleichen Netz)

```bash
export PARSE_SERVER_URL='https://192.168.178.24/parse'
```

### Option B — SSH-Tunnel vom Mac (Remote-Zugriff)

Terminal 1 (Tunnel offen lassen):

```bash
ssh -L 8443:127.0.0.1:443 io@192.168.178.20
```

Terminal 2:

```bash
export PARSE_SERVER_URL='https://127.0.0.1:8443/parse'
# Selbstsigniertes Zertifikat: Script nutzt curl -sk
```

---

## Checkliste — Backend E2E

### Schritt 1 — Jest (schnell, lokal)

```bash
cd backend/parse-server/cloud
npx jest functions/__tests__/tradingPairedBuyExecution.test.js
```

- [ ] Alle Tests grün (COMMITTED/ABORTED Replay, CANCELLED forbidden)

### Schritt 2 — Shell E2E gegen Parse

```bash
cd /path/to/FIN1
export PARSE_SERVER_URL='https://192.168.178.24/parse'   # oder Tunnel-URL
bash scripts/e2e-execute-paired-buy.sh
```

**Erwartete Ausgabe (Auszug):**

```
[e2e] First executePairedBuy OK pairExecutionId=...
[e2e] finalizePairedBuyExecution OK
[e2e] getOpenTrades OK
[e2e] PASS: finalize + replay shows COMMITTED + N leg(s) executed (server settlement).
```

- [ ] Exit-Code `0`
- [ ] Zeile `[e2e] PASS:` sichtbar
- [ ] Zweiter Aufruf: `idempotentReplay=true`, Status `COMMITTED`
- [ ] `getOpenTrades` enthält Trade mit `buyOrderId` = TRADER-Leg

### Schritt 3 — iOS Smoke (optional, gleicher Release)

- [ ] Trader-Login → Suche → KAUFEN → Sheet „Kauf-Order“ mit Quantity-Feld (UITest: `testBuyOrderSheet_OpensWithContent_OnFirstTap` oder manuell)
- [ ] Nach Fehlschlag: „Erneut versuchen“ startet neuen Versuch (neuer Intent)
- [ ] Console/Instruments: `BuyOrderPlacement`-Logs `placement_started` / `placement_finished` / `paired_buy_response`

---

## Abbruchkriterien (Release blockieren)

| Symptom | Aktion |
|---------|--------|
| Duplicate `orderNumber` / Mongo E11000 | Cloud-Deploy + sequentielles Save prüfen (`.cursor/rules/parse-cloud.md`) |
| Replay ohne `idempotentReplay` | `tradingPairedBuyExecution.js` + Unique-Index `PairedExecution` |
| `ABORTED` ohne Retry-UX | iOS `acknowledgeFailure` + „Erneut versuchen“ |
| finalize OK, kein Trade in `getOpenTrades` | `pairedBuyOrchestration.js` / Settlement-Pfad |

---

## Siehe auch

| Ressource | Inhalt |
|-----------|--------|
| `scripts/e2e-execute-paired-buy.sh` | Vollständiger Ablauf Login → execute → finalize → replay |
| `scripts/load-test-paired-buy-parallel.sh` | Last-Probe (optional, GH Action `paired-buy-load-test.yml`) |
| `Documentation/FIN1_APP_DOCS/02A_FEATURE_KATALOG_GUARDRAILS.md` | Buy-Order SSOT, Sheet-Regeln |
