# iOS: Trader Collection Bill — Beleg-SSOT

**Status:** Phase 1–4 umgesetzt (Snapshot + Cloud-Enrichment + Metadata-Detail + Drift-Guard).

**Backend-SSOT:** `traderCollectionBillBelegSnapshot.js` → `Document.metadata` + `accountingSummaryText` auf Parse.

## Zielbild

| Priorität | Quelle | Wann |
|-----------|--------|------|
| 1 | `Document.accountingSummaryText` (Parse) | Klartext-Beleg (Snapshot) |
| 2 | `Document.metadata` (Parse) | Strukturierte Detailansicht (iOS) |
| 3 | `getTraderDocumentBelegDetail` (Session) | Alt-Belege ohne Parse-Felder |
| 4 | `Invoice` | Nur Fallback, orangener Banner |

## Phase 1 ✅ — Klartext-Snapshot

- `TraderCollectionBillBelegSnapshotView`
- `CollectionBillDocumentView` routet Snapshot vor Legacy-Invoice-View

## Phase 2 ✅ — Cloud-Enrichment

- `getTraderDocumentBelegDetail` (Session, eigene Document.userId)
- iOS decodiert `metadata` in `TraderCollectionBillBelegMetadata`

## Phase 3 ✅ — Strukturierte Detailansicht (Metadata-SSOT)

- `TraderCollectionBillLegDisplayDataBuilder` → `TradeStatementDisplayData` ohne Invoice-Synthese
- `CollectionBillViewWrapper` metadata-first; kein `generateInvoicesForCompletedTrades` im Vergleichsmodus
- Grüner Banner: GoB-Server-Metadaten; orange nur bei Invoice-Fallback

## Phase 4 ✅ — Drift & Backfill (Admin)

- **Detection:** `checkTraderCollectionBillBelegDrift` — Snapshot-Text ↔ `metadata` (optional Invoice)
- **Observability:** `getTraderCollectionBillBelegDriftStatus` in `getFinanceIntegrityStatus` + Finance Smoke
- **Repair:** `backfillTraderCollectionBillBeleg` (dry-run → apply) via Finance Repair Catalog
- **iOS:** `Document.traderBelegSnapshotMetadataDrifts()` — Warnbanner bei Abweichung

## Abnahme

1. Neuer TBC/TSC: Snapshot + Detail aus Parse-`metadata`, kein Invoice-Load.
2. TSC Partial Sell: Detail zeigt VERKAUF mit `metadata.quantity` (z. B. 400 St.).
3. Drift: Admin Smoke zeigt `trader_beleg_ssot_drift`; iOS warnt bei Snapshot≠Metadata.
4. Legacy: `backfillTraderCollectionBillBeleg` mit `dryRun:true`, dann `dryRun:false`.
