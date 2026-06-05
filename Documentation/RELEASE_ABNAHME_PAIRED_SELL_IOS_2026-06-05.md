# Release-Abnahme — Paired Buy/Sell → Investor (iOS + iobox)

**Ziel:** Go-Live-Nachweis für den Kernpfad **Paired Buy (Pool) → Paired Sell → Investor Settlement** in der iOS-App gegen iobox-Parse, inkl. Ops-Monitore und iOS-Prävention (keine Client-`ABCDEFG`-Stubs in Parse).

**Referenzen**

- Invarianten: `Documentation/PAIRED_BUY_SELL_INVESTOR_INVARIANTS.md`
- Monitoring: `Documentation/RETURN_PERCENTAGE_MONITORING_AND_ALERTING.md`
- Test-Accounts: `Documentation/DEV_LOGIN_ACCOUNTS.md` (`TestConstants.password`)
- Server-E2E: `scripts/e2e-paired-sell-integrity-smoke.js`

---

## 1) Scope dieser Abnahme

| Bereich | Enthalten | Nicht abgedeckt |
|---------|-----------|-----------------|
| iOS Trader | Paired Buy, Paired Sell, Order-Status ~1 s/Schritt | Vollständiger Regression über alle Trader |
| iOS Investor | Investment → completed nach Sell | Alle Investor-Edge-Cases / Partial Sell |
| Backend | Settlement, Mirror-Sync, Collection Bills | Legacy-Daten in großer Menge |
| Ops | iobox-Cron-Monitore, Return%-Contract | GitHub-Cloud-Runner gegen LAN-Parse |

---

## 2) Voraussetzungen (erfüllt)

| Check | Status |
|-------|--------|
| Parse Cloud auf iobox deployed | ✅ |
| Finance-Integrity + Return%-Monitore (iobox Cron) | ✅ |
| iOS: `DocumentInboxPolicy.shouldSyncDocumentToParse` (Commit `4b912ce`) | ✅ |
| iOS: `OrderStatusConfig.statusStepInterval = 1.0` | ✅ |
| Legacy iOS-Stubs bereinigt (`cleanupLegacyDocumentsAllUsers`, 2026-06-05) | ✅ |

**Git-Ref (Abnahme-Stand):** `4b912ce` (inkl. `55385f8`, `70bfe99`, `c7fb51e`, `4d56fb1`)

**Umgebung:** iobox — `192.168.178.20` / `192.168.178.24`, Parse `~/fin1-server/`

---

## 3) Manuelle Abnahme iOS (2026-06-05)

**Tester:** manuell in der App (Trader + Investor)

| Phase | Account | Schritt | Ergebnis |
|-------|---------|---------|----------|
| 1 | `investor1@test.com` | Investment bei Trader anlegen | ✅ Active Investment sichtbar |
| 2 | `trader1@test.com` | Paired Buy (Pool-Mirror) | ✅ Pool aktiv, Status ~1 s/Schritt |
| 3 | `trader1@test.com` | Paired Sell | ✅ **Trade Nr. 001** `completed` — Profit **650,00 €** (+39,12 %), Commission **74,55 €** |
| 4 | `investor1@test.com` | Investment-Status nach Sell | ✅ **completed** (nicht mehr active) |

**Pass-Kriterien (Phase 4):**

- [x] Trader: Trade `completed`
- [x] Investor: Investment `completed`
- [x] Kein erneuter Return%-Monitor-Alarm durch neue `ABCDEFG`-Parse-Docs (siehe §4)

**Optional noch visuell (nicht im Protokoll ausgefüllt):**

- [ ] Kontoauszug: `investment_return`
- [ ] Inbox: Server-Collection-Bill (CB-…, nicht `investment://` / `ABCDEFG-INVST`)

---

## 4) Ops-Verifikation (iobox, 2026-06-05)

Auf `io@iobox` nach App-Abnahme:

```bash
~/fin1-server/scripts/run-finance-integrity-monitor.sh
~/fin1-server/scripts/run-return-percentage-contract-monitor.sh
```

| Monitor | Ergebnis | Nachweis |
|---------|----------|----------|
| `finance-integrity-monitor` | ✅ Pass (exit 0) | Keine Terminal-Ausgabe (Logs unter `~/fin1-server/logs/`); kein Fehler bei `&&`-Kette |
| `return-percentage-contract-monitor` | ✅ Pass (exit 0) | `missing_return_percentage_count=0` (nach Legacy-Cleanup) |

Log-Check (optional):

```bash
tail -3 ~/fin1-server/logs/finance-integrity-monitor.log
tail -3 ~/fin1-server/logs/return-percentage-contract-monitor.log
```

Erwartung: Zeilen mit `OK … healthy` und `rc=0`.

---

## 5) Abnahmeprotokoll

| Feld | Wert |
|------|------|
| **Datum** | 2026-06-05 |
| **Umgebung** | iobox (`192.168.178.20`) |
| **Git-Ref** | `4b912ce` |
| **Trader-Test** | `trader1@test.com` |
| **Investor-Test** | `investor1@test.com` |
| **Trade** | Nr. 001, Beginn/Ende 05.06.2026, Profit 650 € (+39,12 %) |
| **Investor-Status** | `completed` |
| **Ops-Monitore** | finance-integrity + return%-contract: exit 0 |
| **Go / No-Go** | **Go** |
| **Anmerkungen** | Vollständiger Paired-Sell-Kernpfad in App verifiziert; iOS-Platzhalter-Sync-Prävention aktiv; Server-Monitore SSOT auf iobox-Cron |

---

## 6) No-Go-Kriterien (für künftige Releases)

- Trade `completed`, Investment bleibt `active`
- `run-return-percentage-contract-monitor` → `missing > 0` nach App-Lauf
- `run-finance-integrity-monitor` → `overall != healthy`
- `Document synced to backend` für `investment://`-`investorCollectionBill` direkt nach Investment-Anlage (Regression Prävention)

Bei No-Go: `Documentation/PAIRED_BUY_SELL_INVESTOR_INVARIANTS.md` (Repair-Katalog), `SettlementRetryJob`-Triage auf iobox.
