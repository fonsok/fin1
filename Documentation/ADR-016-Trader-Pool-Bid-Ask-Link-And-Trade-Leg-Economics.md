# ADR-016 – Trader↔Pool: nur Bid/Ask, Domain `tradeLegEconomics`

- **Status:** Accepted
- **Datum:** 2026-06-09
- **Bezug:** `ADR-014`, `legPriceMetrics.js`, `poolMirrorEconomics/`

## Problem

1. Pool-Mirror-Report zeigte Trader-Einstand/Gebühren (z. B. 1.000-Stück-Order auf 797 Pool-Stück).
2. Verkaufsgebühren wurden teils auf Pool-Gesamt-Brutto statt pro Pool-Sell-Order berechnet.
3. `tradeEconomicsSnapshot` lag im Report-Modul — keine Domain-SSOT.

## Entscheidung

### A) Verknüpfung Trader ↔ Pool-Mirror

| Seite | Einzige gemeinsame Größe | Pool rechnet selbst |
|-------|--------------------------|---------------------|
| **Kauf** | **Bid** (nominell/Stück) | Stück, Brutto, Gebühren, Einstand, Pool-Einlage |
| **Verkauf** | **Ask** je Sell-Order | Pool-Δ-Stück, Brutto, Gebühren, Netto, P/L |

Nicht kopieren: Trader-`costBasisPerShare`, `buyFeesTotal`, `totalBuyCost`, Verkaufsgebühren, Nettoerlös.

### B) Domain-SSOT `tradeLegEconomics.js`

- Pfad: `backend/parse-server/cloud/utils/poolMirrorEconomics/tradeLegEconomics.js`
- Export: `tradeEconomicsSnapshot` (Tier-1 über `poolMirrorEconomics` Fassade)
- Report: `summaryReportTradeSnapshot.js` = dünner Re-Export (Abwärtskompatibilität)

### C) Pool-Kauf / Pool-Verkauf

- Kauf: `resolvePoolMirrorBuyMetricsFromBid({ poolPieces, bidPricePerShare, feeConfig })`
- Verkauf: `aggregatePoolSellFromTraderSellOrders` — Gebühren **pro Pool-Order**, Summen in `poolSellFeesTotal` / `poolNetSellAmount`

### D) P/L

- Trader offen: `−totalBuyCost`
- Trader verkauft: `netto − (verkaufte Stück × round2(Einstand))`
- Pool offen: `−poolCapitalAllocated`
- Pool verkauft: Pool-Netto − (Pool-Stück × Pool-Einstand)

## Konsequenzen

- Summary Report importiert Domain, keine Gebührenformeln im Report.
- Phase 2 (Snapshot-Dedup im Report) und Phase 3 (persistierte Economics) bauen auf dieser Domain auf.
