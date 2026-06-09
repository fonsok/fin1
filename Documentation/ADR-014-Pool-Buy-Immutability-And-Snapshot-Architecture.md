# ADR-014 – Pool Buy Immutability & Snapshot-First Architecture

- **Status:** Accepted
- **Datum:** 2026-06-06
- **Bezug:** `ADR-012`, `ADR-010-Settlement-GL-Posting`, GOBD §146 Abs. 4 AO

## Problem

1. **GOBD-Verstoß:** `pairedTradeMirrorSync` überschrieb die Kaufseite des Mirror-Trades (`quantity`, `buyAmount`) bei jedem Teilverkauf → Admin-Report zeigte instabile Kaufpreise/Stückzahlen.
2. **Abgeleitete Anzeige:** Summary Report berechnet Pool-Metriken live aus mutablen Trade-Feldern statt aus eingefrorenen Ausführungsdaten → fragil, ressourcenintensiv, schwer nachvollziehbar.
3. **Dateigröße:** `summaryReportTradePoolEnrichment.js` (787 Zeilen) mischt 5 Zuständigkeiten → schwer wartbar.

## Entscheidung

### A) Immutable Buy Fields (Trade)

Folgende Felder sind nach Buy-Execution **unveränderlich** (keine `set()` mehr):

- `buyOrderId`, `buyOrder`, `quantity`, `buyPrice`, `buyAmount`, `pairExecutionId`

**Enforcement:**
- `pairedTradeMirrorSync/sellSync.js` → `applyMirrorSellSyncFromTraderLeg` (package-internal, nicht auf Fassade) darf nur Sell-Felder setzen.
- Guard-Test (`summaryReportPoolBuyImmutability.test.js`) sichert Regression ab.

### B) Pool Buy Snapshot auf PoolTradeParticipation

Bei Pool-Aktivierung (`poolMirrorActivationService`) wird ein **`buySnapshot`** persistiert:

```json
{
  "buyPrice": 1.66,
  "costBasisPerShare": 1.67,
  "buyFeesTotal": 11.30,
  "totalBuyCost": 1671.30,
  "bidPricePerShare": 1.66,
  "poolPieces": 598,
  "poolCapitalAllocated": 992.68,
  "investmentAmount": 1000,
  "snapshotAt": "2026-06-06T10:00:00.000Z"
}
```

**Quelle:** Trader-Buy-Leg via `legPriceMetrics.tradeBuySideMetrics`.
**Regel:** Snapshot einmal schreiben, nie updaten.

### C) Summary Report: Snapshot-First

Pool-Mirror-Metriken (Bid, Einstand, Gebühren, Stück) werden primär aus `buySnapshot` gelesen. Recompute via `aggregatePoolInvestmentEconomics` nur als Fallback für Legacy-Daten ohne Snapshot.

### D) Dateigrößen ≤ 300 Zeilen

`summaryReportTradePoolEnrichment.js` (787) wird aufgeteilt:

| Neue Datei | Zuständigkeit | ~Zeilen |
|------------|---------------|---------|
| `summaryReportTradeSnapshot.js` | `tradeEconomicsSnapshot`, `applyPoolMirrorEconomicsOverrides`, `resolveImmutableBuyInputs` | ~120 |
| `summaryReportPairedLegResolver.js` | `resolvePairedLegContextsByTradeId`, `loadTradesById`, `resolveTraderAndPoolObjects`, `resolvePoolParticipationsForRow`, `applyPoolMirrorFromParticipations` | ~200 |
| `summaryReportParticipationLoader.js` | `loadParticipationsByPoolTradeIds`, `mapParticipationRow`, `enrichParticipationDisplayFields` | ~130 |
| `summaryReportTradePoolEnrichment.js` | `enrichSummaryReportTrades`, `ensureMirrorLinkForTraderRows`, `ensureTraderLinkForPoolRows`, `attachPartialSellEventsToSummaryRows` (orchestrator only) | ~200 |

`poolMirrorEconomics.js` (346) und `settlementDeltas.js` (334): je 20–40 Zeilen kürzen durch Extraktion gemeinsamer Queries in bestehende Helpers.

### E) Kein „Kaufvolumen" im Pool-Mirror-Block

Pool-Mirror zeigt nur: Reserved, Pool-Einlage, Residual, Stück, Bid, Einstand, Gebühren.
Kein kumulatives „Kaufvolumen" — die Einzelfelder sind selbsterklärend.

## Konsequenzen

- **GOBD:** Kaufseite stabil, Abweichung = Datenfehler, nicht Softwarefehler.
- **Performance:** Snapshot-Read statt n×`computeInvestorBuyLeg` pro Report-Aufruf.
- **Wartung:** Jede Datei ≤ 300 Zeilen, eine Zuständigkeit.
- **Migration:** Legacy Participations ohne `buySnapshot` → Fallback-Recompute, kein Schema-Break.

## Nicht-Ziele

- Kein neuer Parse-Klasse (`PartialSellEvent`) in dieser Phase — `sellOrders[]` + Belege reichen für Traceability.
- Keine Reparatur bereits mutierter Mirror-Trades in dieser Phase (separates Backfill-Script).
