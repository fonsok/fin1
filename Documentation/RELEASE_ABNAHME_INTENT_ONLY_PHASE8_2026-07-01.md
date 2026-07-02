# Release-Abnahme — Intent-only Execution + MarketData Feed (ADR-019 Phase 8–9)

**Ziel:** Go-Live-Nachweis für **intent-only** Market-Orders (kein Client-`price` in Execute-Payloads), den **serverseitigen Market-Data-Feed** und **iOS feed-first** mit `upsertMarketDataQuote` als Fallback.

**Referenzen**

- ADR: `Documentation/ADR-019-Sell-Server-Authoritative-Execution.md` (Phase 8–9)
- Preis-Resolver: `backend/parse-server/cloud/utils/executionPriceResolver.js`
- Feed: `backend/parse-server/cloud/utils/marketDataFeed/`
- Cloud Functions: `upsertMarketDataQuote`, `runMarketDataFeedRefresh`
- iOS: `FIN1/Shared/Services/MarketDataQuotePublisher.swift`
- E2E-Smokes: `scripts/smoke-publish-market-data-quote-e2e.sh`, `scripts/smoke-market-data-feed-e2e.sh`
- Unit-Tests: `FIN1Tests/MarketDataQuotePublisherTests.swift`
- Test-Accounts: `Documentation/DEV_LOGIN_ACCOUNTS.md`

---

## 1) Scope dieser Abnahme

| Bereich | Enthalten | Nicht abgedeckt |
|---------|-----------|-----------------|
| Backend | Intent-only Resolver, Feed-Worker, `upsertMarketDataQuote` (Fallback) | Echter externer Market-Data-Service (`backend/market-data/`) |
| iOS Trader | Feed-first vor Market-Buy/Sell; Upsert nur bei fehlendem/stale Quote | Vollständige Trader-Regression |
| Ops | Post-Deploy-Smoke full profile inkl. Feed + Upsert E2E | Produktions-App-Store-Release (manuell) |
| Monetary SSOT | P0 #2 Fees/Belege | Separates Ticket |

---

## 2) Voraussetzungen (erfüllt)

| Check | Status |
|-------|--------|
| Parse Cloud auf iobox deployed (intent-only, Feed, `upsertMarketDataQuote`) | ✅ |
| Post-Deploy-Smoke `upsertMarketDataQuote` E2E | ✅ |
| Post-Deploy-Smoke `market data feed` E2E | ✅ |
| Post-Deploy-Smoke full profile (Deploy 2026-07-02) | ✅ |
| iOS: `MarketDataQuotePublisher` feed-first + Buy/Sell Hooks | ✅ |
| iOS Unit-Tests `MarketDataQuotePublisherTests` (3/3) | ✅ (2026-07-02) |
| ADR-019 Phase 8–9 dokumentiert | ✅ |

**Umgebung:** iobox — `192.168.178.20`, Parse `~/fin1-server/`, App → Staging-Parse (Simulator)

**Git-Ref (Abnahme-Stand):**

| Commit | Inhalt |
|--------|--------|
| `b3bcad3` | Intent-only + `upsertMarketDataQuote` Brücke |
| `c8c4cfb` | Server-Feed + iOS feed-first |
| `b408068` | Feed: Katalog + kürzlich gehandelte Symbole |

---

## 3) iOS feed-first Check (2026-07-02)

**Tester:** automatisiert (Unit-Tests + API-Mirror gegen iobox)

### Szenario A — Feed-WKN (`865985`, Apple)

| Schritt | Erwartung | Ergebnis |
|-------|-----------|----------|
| `runMarketDataFeedRefresh` | Frische `MarketData` | ✅ price≈174, age≤300s |
| iOS-Logik (`ensureFreshMarketDataBeforeExecution`) | **Kein** `upsertMarketDataQuote` | ✅ skip upsert |

### Szenario B — Exotische WKN (noch nie gehandelt)

| Schritt | Erwartung | Ergebnis |
|-------|-----------|----------|
| Vor Upsert | Kein `MarketData` | ✅ |
| iOS-Logik | **Upsert-Fallback** | ✅ `upsertMarketDataQuote` |
| Nach Upsert | Frische Quote, Execute möglich | ✅ |

### Unit-Tests (Simulator iPhone 16)

| Test | Ergebnis |
|------|----------|
| `testSkipsUpsertWhenFeedQuoteIsFresh` | ✅ |
| `testUpsertsWhenFeedQuoteMissing` | ✅ |
| `testUpsertsWhenFeedQuoteStale` | ✅ |

**Pass-Kriterien Phase 9 (Client):**

- [x] Feed-WKN: Upsert wird übersprungen bei Quote ≤ 300s
- [x] Exotische WKN: Upsert-Fallback funktioniert
- [x] Stale Quote (>300s): Upsert wird ausgelöst
- [x] Unit-Tests grün

**Optional (nicht im Protokoll ausgefüllt):**

- [ ] Xcode-Konsole im Simulator: Market-Buy `865985` ohne `upsertMarketDataQuote`-Log
- [ ] Separater Market-Sell-Only-Durchlauf dokumentiert
- [ ] Limit-Order (ohne Publish) Regression

---

## 4) Automatisierte Verifikation (iobox)

| Check | Ergebnis |
|-------|----------|
| `scripts/smoke-publish-market-data-quote-e2e.sh` | ✅ |
| `scripts/smoke-market-data-feed-e2e.sh` | ✅ |
| Deploy Parse Cloud + full post-deploy-smoke | ✅ (2026-07-02) |
| API-Mirror feed-first (865985 + exotische WKN) | ✅ (2026-07-02) |

**Upsert-Smoke** (Fallback-Pfad):

1. `executePairedBuy` ohne Quote → `no market data`
2. `upsertMarketDataQuote` (Trader-Session)
3. `executePairedBuy` → Preisauflösung OK

**Feed-Smoke** (Hauptpfad):

1. `runMarketDataFeedRefresh` für Feed-WKN
2. `MarketData` frisch vorhanden
3. `executePairedBuy` ohne Upsert → Preisauflösung OK

---

## 5) Abnahmeprotokoll

| Feld | Wert |
|------|------|
| **Datum Abnahme** | 2026-07-02 |
| **Datum Welle geschlossen** | 2026-07-02 |
| **Umgebung** | iobox (`192.168.178.20`) |
| **iOS** | Unit-Tests + API-Mirror; TestFlight hochgeladen (Processing 🟡) |
| **Git-Ref** | `c0de3b9` (+ Docs `44223a9`) |
| **Automatisierter Check** | ✅ feed-first 2-Szenario + 3 Unit-Tests |
| **Backend-Deploy** | ✅ Parse Cloud (intent-only + Feed Slice 1–3) |
| **CI** | ✅ GitHub `main` |
| **Ergebnis** | **Geschlossen** — Phase 8–9 Welle abgeschlossen |

**Bemerkungen:**

- **Hauptpfad:** Server-Feed (Mock-Katalog + kürzlich gehandelte WKNs, 60s Worker) → Parse `MarketData` → `executionPriceResolver`.
- **Fallback:** `upsertMarketDataQuote` bleibt für erstmalige/exotische WKNs ohne Feed-Quote (bewusst nicht entfernen).
- Alte iOS-Builds ohne feed-first schicken ggf. weiter Upsert — harmlos. Builds **ohne** Publish **und** ohne Feed-Quote schlagen bei Market-Orders fehl.

---

## 6) Enthaltene Änderungen

### Phase 8 — Intent-only

| Pfad | Inhalt |
|------|--------|
| `backend/parse-server/cloud/utils/executionPriceResolver.js` | Intent-only: nur `MarketData` / `limitPrice` |
| `backend/parse-server/cloud/functions/upsertMarketDataQuote.js` | Fallback-Quote in `MarketData` |
| `FIN1/Shared/Services/MarketDataQuotePublisher.swift` | Publish / feed-first vor Market-Execute |
| `FIN1/Features/Trader/Services/BuyOrderPlacementService+PairedBuy.swift` | Hook Buy |
| `FIN1/Features/Trader/Services/OrderAPIService.swift` | Hook Sell |
| `scripts/smoke-publish-market-data-quote-e2e.sh` | E2E Fallback |

### Phase 9 — Server-Feed + iOS feed-first

| Pfad | Inhalt |
|------|--------|
| `backend/parse-server/cloud/utils/marketDataFeed/` | Feed-Worker, Katalog, Trade-Discovery |
| `backend/parse-server/cloud/functions/runMarketDataFeedRefresh.js` | Admin/Ops manueller Refresh |
| `backend/parse-server/cloud/main.js` | 60s Worker |
| `FIN1Tests/MarketDataQuotePublisherTests.swift` | feed-first Unit-Tests |
| `scripts/smoke-market-data-feed-e2e.sh` | E2E Feed-Hauptpfad |

---

## 7) Welle geschlossen (2026-07-02)

| # | Aktion | Status |
|---|--------|--------|
| 1 | iOS TestFlight Upload (`c0de3b9`) | ✅ Hochgeladen — 🟡 Processing |
| 2 | Geräte-Kurztest nach grünem Build | ⏳ Optional |
| 3 | Echter Market-Data-Service (`backend/market-data/`) | Backlog (Slice 4) |
| 4 | P0 #2 Fees/Belege | Backlog |

**Parse-Cloud-Deploy:** Stand 2026-07-02 live auf iobox — kein weiterer Deploy für diese Welle.

**Nächste Produktwelle (separat):** Growth Attribution G1 — Code noch nicht auf `main`; eigener Commit → CI → TestFlight.
