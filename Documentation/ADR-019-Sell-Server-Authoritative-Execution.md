# ADR-019 – Sell: Server-Authoritative Execution (Symmetrie zu Paired Buy)

- **Status:** Accepted (Phase 1a implemented 2026-06-17)
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

### Phase 1b (nächster Schritt) — `executePairedSell` oder `placeSellOrder` Cloud Function

Analog `executePairedBuy`:

- Idempotenz via `clientOrderIntentId`
- Atomare Leg-Persistenz + Server-Fees (`calculateOrderFees`)
- Kein direkter Client-`createObject` für produktionskritische Sells

**Trigger:** Teil-Verkauf-Volumen, Paired-Leg-Kopplung oder Audit-Anforderung an eine einzige Orchestrierungs-API.

### Phase 2 — Legacy-Cleanup (siehe Gap-Roadmap)

- Lokale Settlement-Fallbacks entfernen (nur Tests)
- ADR-009 `collectionBillServerLegs` abschließen
- Saldo-UI an `UserCashBalance` / `getAccountStatement` koppeln

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

## Referenzen

| Thema | Pfad |
|-------|------|
| Preis-Resolver | `backend/parse-server/cloud/utils/executionPriceResolver.js` |
| Order beforeSave | `backend/parse-server/cloud/triggers/orderTriggerBeforeSave.js` |
| iOS Sell persist | `FIN1/Features/Trader/Services/OrderAPIService.swift` |
| Paired Buy SSOT | `backend/parse-server/cloud/functions/tradingPairedBuyExecution.js` |
