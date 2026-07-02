# Release-Abnahme — Intent-only Execution + MarketData Publish (ADR-019 Phase 8)

**Ziel:** Go-Live-Nachweis für **intent-only** Market-Orders (kein Client-`price` in Execute-Payloads) und die **Interim-Brücke** `upsertMarketDataQuote` → Parse `MarketData` → `executePairedBuy` / `executeSellOrder`.

**Referenzen**

- ADR: `Documentation/ADR-019-Sell-Server-Authoritative-Execution.md` (Phase 8)
- Preis-Resolver: `backend/parse-server/cloud/utils/executionPriceResolver.js`
- Cloud Function: `backend/parse-server/cloud/functions/upsertMarketDataQuote.js`
- iOS Publish: `FIN1/Shared/Services/MarketDataQuotePublisher.swift`
- E2E-Smoke: `scripts/smoke-publish-market-data-quote-e2e.sh`
- Test-Accounts: `Documentation/DEV_LOGIN_ACCOUNTS.md`

---

## 1) Scope dieser Abnahme

| Bereich | Enthalten | Nicht abgedeckt |
|---------|-----------|-----------------|
| Backend | Intent-only Resolver, `upsertMarketDataQuote`, Deploy iobox | Serverseitiger Dauer-Market-Data-Feed |
| iOS Trader | Market-Buy/Sell mit Publish vor Execute | Vollständige Trader-Regression |
| Ops | Post-Deploy-Smoke inkl. `upsertMarketDataQuote` E2E | Produktions-App-Store-Release (manuell) |
| Monetary SSOT | P0 #2 Fees/Belege | Separates Ticket |

---

## 2) Voraussetzungen (erfüllt)

| Check | Status |
|-------|--------|
| Parse Cloud auf iobox deployed (`upsertMarketDataQuote`, intent-only Resolver) | ✅ |
| Post-Deploy-Smoke `upsertMarketDataQuote E2E` (Server localhost) | ✅ |
| Post-Deploy-Smoke full profile (Deploy 2026-07-01) | ✅ |
| iOS: `MarketDataQuotePublisher` + Buy/Sell Placement-Hooks | ✅ (lokaler Build) |
| ADR-019 Phase 8 dokumentiert | ✅ |

**Umgebung:** iobox — `192.168.178.20`, Parse `~/fin1-server/`, App → Staging-Parse (Simulator)

**Git-Ref (Abnahme-Stand):** Lokaler Build mit Phase-8-Änderungen (Commit noch ausstehend; `main` @ `048701f` + uncommittete Phase-8-Dateien siehe §6)

---

## 3) Manuelle Abnahme iOS (2026-07-01)

**Tester:** manuell im **Simulator**, App neu gebaut mit Phase-8-Swift-Änderungen

| Phase | Schritt | Ergebnis |
|-------|---------|----------|
| 1 | Neuer Geschäftsfall (Trader): Market-Order-Flow | ✅ In Ordnung |
| 2 | Kein Fehler `no market data` / `market data stale` | ✅ (implizit — Durchlauf erfolgreich) |
| 3 | Order/Trade wie erwartet abgeschlossen | ✅ In Ordnung |

**Pass-Kriterien Phase 8 (Client):**

- [x] Market-Order im Simulator ohne Market-Data-Fehler
- [x] Geschäftsfall vollständig durchlaufen
- [x] Neuer iOS-Build (nicht alte App-Version)

**Optional (nicht im Protokoll ausgefüllt):**

- [ ] Xcode-Konsole: `upsertMarketDataQuote` vor `executePairedBuy` sichtbar
- [ ] Separater Market-Sell-Only-Durchlauf dokumentiert
- [ ] Limit-Order (ohne Publish) Regression

---

## 4) Automatisierte Verifikation (iobox)

| Check | Ergebnis |
|-------|----------|
| `scripts/smoke-publish-market-data-quote-e2e.sh` (lokal + Server) | ✅ |
| Deploy Parse Cloud + full post-deploy-smoke | ✅ (2026-07-01) |

Smoke-Ablauf (ohne Master-Key-`MarketData`-Seed):

1. `executePairedBuy` ohne Quote → `no market data`
2. `upsertMarketDataQuote` (Trader-Session)
3. `executePairedBuy` → Preisauflösung OK (Mindest-Kaufbetrag-Block)

---

## 5) Abnahmeprotokoll

| Feld | Wert |
|------|------|
| **Datum** | 2026-07-01 |
| **Umgebung** | iobox (`192.168.178.20`) |
| **iOS** | Simulator, neu gebaut |
| **Manuelle Abnahme** | ✅ Geschäftsfall in Ordnung |
| **Backend-Deploy** | ✅ Parse Cloud (intent-only + `upsertMarketDataQuote`) |
| **Ergebnis** | **Go** — Phase-8-Client-Lücke geschlossen (interim) |

**Bemerkungen:** `upsertMarketDataQuote` ist bewusst **Interim** bis ein serverseitiger Market-Data-Feed existiert (ADR-019 Phase 8). Alte iOS-Builds ohne Publish schlagen bei Market-Orders fehl, sofern kein externes `MarketData` existiert.

---

## 6) Enthaltene Änderungen (Phase 8)

| Pfad | Inhalt |
|------|--------|
| `backend/parse-server/cloud/utils/executionPriceResolver.js` | Intent-only: nur `MarketData` / `limitPrice` |
| `backend/parse-server/cloud/functions/upsertMarketDataQuote.js` | Quote in `MarketData` schreiben |
| `backend/parse-server/cloud/functions/trading.js` | CF registriert |
| `FIN1/Shared/Services/MarketDataQuotePublisher.swift` | iOS Publish vor Market-Execute |
| `FIN1/Features/Trader/Services/BuyOrderPlacementService+PairedBuy.swift` | Hook Buy |
| `FIN1/Features/Trader/Services/OrderAPIService.swift` | Hook Sell |
| `scripts/smoke-publish-market-data-quote-e2e.sh` | E2E ohne Master-Key-Seed |
| `Documentation/ADR-019-Sell-Server-Authoritative-Execution.md` | Phase 8 Addendum |

---

## 7) Nächste Schritte nach Abnahme

| # | Aktion | Priorität |
|---|--------|-----------|
| 1 | Phase-8-Änderungen committen + iOS Release (TestFlight/intern) | Jetzt |
| 2 | Serverseitiger Market-Data-Feed (ersetzt App-Publish) | Backlog |
| 3 | P0 #2 Fees/Belege | Backlog |

**Kein weiterer Parse-Cloud-Deploy** für diese Welle erforderlich (bereits live).
