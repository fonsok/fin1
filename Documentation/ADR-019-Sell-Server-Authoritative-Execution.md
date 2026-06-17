# ADR-019 – Sell: Server-Authoritative Execution (Symmetrie zu Paired Buy)

- **Status:** Accepted (Phase 1a–2, 3a–3b implemented 2026-06-17)
- **Datum:** 2026-06-17
- **Bezug:** `BACKEND_CALCULATION_MIGRATION.md`, `executionPriceResolver.js`, `executePairedBuy`, ADR-018, Gap-Analyse Monetary SSOT (2026-06)

## Kontext

Käufe mit Pool-Spiegel laufen über **`executePairedBuy`**: Intent (Menge, Symbol, Order-Typ), Server löst den Ausführungspreis via **`resolvePairedBuyExecutionPrice`** auf und persistiert Orders mit `executionPriceSource` / `serverReferencePrice`.

**Verkäufe** liefen bislang über **`OrderAPIService.saveSellOrder`** → Parse `Order` `beforeSave`, aber **`orderTriggerBeforeSave` wendete `resolveOrderExecutionPrice` nur auf `side === 'buy'` an**. Der Client setzte `price`, `grossAmount` und `totalAmount` aus UI-Schätzungen (`estimatedProceeds`). Das widerspricht dem Zielbild „Server = mathematische Wahrheit“ und der Buy-Symmetrie.

Dies ist **kein** „Client↔Server-Doppelrechner mit Cent-Gate“, sondern **ein autoritativer Server-Pfad** mit optionalem Client-Preis-Hint (wie bei Buy).

## Entscheidung

### Phase 1a (jetzt) — `Order.beforeSave` für Sell

1. **`orderTriggerBeforeSave`:** `resolveOrderExecutionPrice` + `applyExecutionPriceMetaToOrder` für **neue** Sell-Orders, wenn weder `executionPriceSource` noch `pairExecutionId` gesetzt sind (gleiche Ausnahme wie Buy).
2. **iOS `ParseOrderInput.from(sellOrder:)`:** `clientQuotedAt` mitsenden (wie Buy), damit Market-Orders eine frische Quote und MarketData-Toleranzprüfung erhalten.
3. **UI:** `estimatedProceeds` / „Erlös (geschätzt)“ bleiben reine Vorschau; Buchungsrelevant ist der nach `beforeSave` persistierte Order-Satz.

### Phase 1b (implemented 2026-06-17) — `executeSellOrder` Cloud Function

1. **`executeSellOrder`:** Server-orchestrierter Sell-Intent (`quantity`, `symbol`, `tradeId`, `clientOrderIntentId`); idempotent pro Trader+Intent; Preis via `resolveOrderExecutionPrice`; Fees via `calculateOrderFees`.
2. **iOS `OrderAPIService.saveSellOrder`:** ruft `executeSellOrder` statt direktem `createObject`; `clientOrderIntentId` = lokale `order.id` (Retry-sicher).
3. **`placeOrder` CF:** Sell erhält dieselbe Preis-Auflösung wie Buy (Legacy-API-Parität).

### Phase 1c (optional) — Sell-Finalize-Orchestrierung

Analog `commitPairedBuyExecution` für Sell-Status-Kopplung — nur wenn Paired-Sell-Legs oder Teil-Verkauf-Volumen es erfordern.

### Phase 2 — Legacy-Cleanup (implemented 2026-06-17)

Analog **P3b** (`InvoiceLocalSynthesisGate`):

1. **`InvestorCollectionBillLocalCalculationGate`:** `calculateCollectionBill(input:)` und `summarizeInvestment` nur in Tests via `withPermitted`.
2. **`calculateCollectionBillWithBackend`:** kein `localFallbackAfterBackendError` mehr — fehlender Beleg → `InvestorMonetaryServerOnlyError`.
3. **Prod-Call-Sites:** ViewModels, `InvestmentCashDistributor`, `ProfitDistributionService`, `OrderLifecycleCoordinator+Settlement` (Credit Note) ohne lokale Monetary-Fallbacks.
4. **Listen/Detail:** `canonicalSummaries` / `summarizeInvestmentFromServer` statt lokaler Aggregator-Summaries.

### Phase 3a — Saldo-Anzeige iOS (implemented 2026-06-17)

1. **iOS customer display:** Closing balance aus `getAccountStatement` merge — identisch Admin „Kundensicht“.
2. **Saldo-Fix:** kein `UserCashBalance`/Client-Recalc mit doppelten Wallet-Zeilen.

### Phase 3b — UserCashBalance Reconciliation (implemented 2026-06-17)

1. **`customerClosingBalance.js`:** Closing aus Investor/Trader Merge-Timeline.
2. **`getUserCashBalance`:** `source: customer_timeline`; Drift-Audit vs. Mongo-Counter.
3. **Seed + Backfill:** `ensureUserCashBalanceSeeded` / `backfillUserCashBalanceFromStatements` auf Kundensicht.

### Phase 6 — ADR-009 `collectionBillServerLegs` (implemented 2026-06-17)

1. Config `display.collectionBillServerLegs` (default `true`) — Admin + iOS.
2. iOS `calculateCollectionBillWithBackend`: reads `metadata.buyLeg`/`sellLeg`; incomplete → `serverLegsPending` (not local recompute).
3. Local `calculateCollectionBill` remains test-only (`InvestorCollectionBillLocalCalculationGate`).

### Phase 7 — ADR-018 cent-alignment ops audit (implemented 2026-06-17)

`checkAccountStatementCentAlignment` + `scripts/check-account-statement-cent-alignment.sh` (in `check-monetary-ssot-health.sh`).

### Phase 3b ops — Drift inspect (implemented 2026-06-17)

1. **`checkUserCashBalanceDrift`:** server-side inspect all users vs customer timeline.
2. **`scripts/check-user-cash-balance-drift.sh`:** ops wrapper (exit 0/2).
3. **Backfill ausgeführt:** 27/27 User auf Kundensicht; Drift-Check `healthy`.

### Phase 4 — Settlement GL Outbox (ADR-017, live on FIN1 prod)

Async GL posting: `AccountStatement` + `SettlementOutbox` in Mongo-Transaction; Worker in `main.js` (45s).

| Check | Tool |
|-------|------|
| Outbox queue + GL recon | `scripts/check-settlement-gl-outbox-health.sh` |
| Drain backlog | `scripts/run-settlement-gl-outbox-drain.sh` |
| UserCashBalance drift | `scripts/check-user-cash-balance-drift.sh` |
| Combined | `scripts/check-monetary-ssot-health.sh` |

**Prod-Baseline (2026-06-17):** `settlementGLOutboxEnabled=true` (live Config, 4-Augen); outbox `posted=54`, `pending/failed=0`; `getSettlementGLReconciliationStatus` → `healthy`.

**Rollback:** Admin Config `settlementGLOutboxEnabled=false` (4-Augen) — synchroner GL-Pfad in `settlementGLPoster.js` greift wieder; Outbox-Queue vorher leeren.

**Nicht ändern:** `defaultConfig.js` auf `true` setzen — Flag nur über live Config / Admin.


- Saldo-UI an `UserCashBalance` / `getAccountStatement` koppeln (→ Phase 3)

## Nicht-Ziele

- Cent-genauer Client↔Server-Vergleich als Ausführungs-Gate
- Vollständige Derivate-Margin-Engine
- Ersetzen von `executePairedBuy` durch Client-Berechnungen

## Konsequenzen

**Positiv**

- Sell-Preis folgt derselben MarketData-/Toleranz-Logik wie Buy
- Weniger Drift zwischen UI-Schätzung und Invoice/Settlement
- Inkrementeller Schritt ohne großes CF-Refactor

**Akzeptiert**

- Sell-Orchestrierung bleibt bis Phase 1b verteilt (`submitOrder` → Parse)
- Paired-Sell-Sync weiter über bestehende Trade/Order-Trigger

## Akzeptanzkriterien Phase 1a

- [x] Neue Sell-`Order` ohne `executionPriceSource` erhalten Server-`price` + `grossAmount`
- [x] iOS sendet `clientQuotedAt` bei Sell-Create
- [x] Regressionstests für Monetary Server-Only Policy (iOS)
- [ ] Staging: Sell-Invoice `grossAmount` = Server-`executionPrice` × `quantity` (manuell)

## Akzeptanzkriterien Phase 1b

- [x] `executeSellOrder` Cloud Function mit Idempotenz (`clientOrderIntentId`)
- [x] iOS `saveSellOrder` nutzt `executeSellOrder` (kein direktes `createObject`)
- [x] Unit-Tests Backend + iOS

## Referenzen

| Thema | Pfad |
|-------|------|
| Preis-Resolver | `backend/parse-server/cloud/utils/executionPriceResolver.js` |
| Order beforeSave | `backend/parse-server/cloud/triggers/orderTriggerBeforeSave.js` |
| iOS Sell persist | `FIN1/Features/Trader/Services/OrderAPIService.swift` |
| Paired Buy SSOT | `backend/parse-server/cloud/functions/tradingPairedBuyExecution.js` |
| Sell SSOT | `backend/parse-server/cloud/functions/tradingSellOrderExecution.js` |
| iOS Sell placement | `FIN1/Features/Trader/Services/OrderAPIService.swift` |
