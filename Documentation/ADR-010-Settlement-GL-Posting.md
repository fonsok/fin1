# ADR-010 – Settlement GL Posting (Trade, Provision, Steuer im App‑Hauptbuch)

- Status: Proposed → Accepted (Phase 1)
- Datum: 2026-04-29
- Author: Engineering / Accounting
- Bezug: `Documentation/LEDGER_CHART_OF_ACCOUNTS_ROADMAP.md` (PR4),
  `Documentation/INVESTMENT_ESCROW_LEDGER_SKETCH.md`,
  `Documentation/ADR-007-App-Service-Charge-Cash-Balance-Debit.md`

## Kontext

Das App‑Hauptbuch (`AppLedgerEntry`) deckt heute **drei** Ereignisfamilien ab:

1. **Investment‑Escrow** (Customer‑Liability‑Subledger): `CLT-LIAB-AVA ↔ RSV ↔ TRD`,
   gepflegt in `backend/parse-server/cloud/utils/accountingHelper/investmentEscrow.js`
   und ausgelöst aus `triggers/investment.js`.
2. **App‑Service‑Charge** (Servicegebühr inkl. USt): voller Buchungssatz
   `S CLT-LIAB-AVA / H PLT-REV-PSC + PLT-TAX-VAT` aus `triggers/invoice/`,
   plus `BankContraPosting` für `BANK-PS-NET` / `BANK-PS-VAT`.
3. **Manuelle 4‑Eyes‑Korrekturen** in `functions/admin/fourEyes/corrections.js`.

Trade‑Settlement (`utils/accountingHelper/settlement.js`) – also Wertpapierkauf/-verkauf,
Handelsgebühren, Provision, Quellensteuer, Soli, Kirchensteuer, Residual‑Return –
wird ausschließlich über `AccountStatement` (+ Beleg via `referenceDocumentId`) und
punktuell `WalletTransaction` abgebildet. Es gibt **keine** zugehörigen
`AppLedgerEntry`‑Legs.

Folgen für Reporting / GoBD / DATEV‑Übergabe:

- Erlöskonten `PLT-REV-COM`, `PLT-REV-ORD`, `PLT-REV-EXC`, `PLT-REV-FRG` sind im
  Kontenrahmen definiert, im Mapping aufgeführt – aber im DB‑Bestand nie bebucht.
- Quellensteuer/Soli/Kirchensteuer existieren als FA‑Verbindlichkeiten nur in der
  Personenkonten‑Sicht (`AccountStatement`), nicht im Hauptbuch.
- Trader‑Trade ↔ Pool‑Mirror‑Trade ist nur über Fremdschlüssel
  (`PoolTradeParticipation.tradeId`) verbunden, nicht buchhalterisch.
- `getAppLedger` synthetisiert Order‑Fee‑Rows aus `Invoice.feeBreakdown` nur dann,
  wenn die `AppLedgerEntry`‑Tabelle leer ist (`appLedger.js` `if (entries.length === 0)`).
  In Produktion mit Escrow‑Buchungen ist sie nie leer → Order‑Fees verschwinden
  aus dem Report.

Gleichzeitig sind die Bausteine für Revisionssicherheit längst da:

- „Beleg vor Buchung“ ist im Settlement durchgängig umgesetzt
  (`createTradeExecutionDocument`, `createCreditNoteDocument`,
  `createCollectionBillDocument`, `createWalletReceiptDocument`).
- Idempotenz‑Wächter pro `entryType` + `source: 'backend'` verhindert
  Doppelbuchungen.
- `accountMappingResolver.js` liefert SKR03/Version/VAT‑Snapshots pro Konto.

## Entscheidung

Wir ergänzen das Settlement um **doppelte Buchungssätze auf `AppLedgerEntry`**.
`AccountStatement` bleibt **Personenkonto / Beleg‑Sicht**, `AppLedgerEntry` wird
zur **Hauptbuch‑Sicht** (GL).
Die Verklammerung erfolgt über `referenceDocumentId` (Beleg), `referenceId` (Trade
bzw. Investment) und einen `accountStatementEntryId`‑Verweis im Metadaten‑Snapshot.

### Schreibpfad

Ein neuer Helper `utils/accountingHelper/journal.js#postLedgerPair` postet ein
balanciertes Soll‑/Haben‑Pair atomar (`Parse.Object.saveAll`) und konsumiert die
bestehende Mapping‑Snapshot‑Mechanik (`applyLedgerSnapshotToEntry`).
`utils/accountingHelper/statements.js#bookSettlementEntry` ist der neue, dünne
Wrapper, der pro `entryType`

1. den Beleg (bereits vom Aufrufer erzeugt) erwartet,
2. die `AccountStatement`‑Zeile schreibt (`bookAccountStatementEntry` unverändert),
3. dann das passende GL‑Pair via `postLedgerPair` schreibt.

Damit bleibt `settle{And,Participation}` minimal verändert: alle bestehenden
Aufrufer von `bookAccountStatementEntry` werden auf `bookSettlementEntry`
umgeschaltet, ohne dass Logik in `settlement.js` umzieht.

### Mapping `entryType` → GL‑Pair

| `entryType` | Soll | Haben | Konventions‑Begründung |
| --- | --- | --- | --- |
| `commission_credit` (Trader) | `PLT-LIAB-COM` | `CLT-LIAB-AVA` | Plattform begleicht Verbindlichkeit gegenüber Trader; Trader‑Cash steigt. |
| `commission_debit` (Investor) | `CLT-LIAB-AVA` | `PLT-LIAB-COM` | Investor zahlt Provision; Plattform schuldet diese dem Trader. |
| `withholding_tax_debit` | `CLT-LIAB-AVA` | `PLT-TAX-WHT` | Quellensteuer; Plattform schuldet dem FA. |
| `solidarity_surcharge_debit` | `CLT-LIAB-AVA` | `PLT-TAX-SOL` | Soli analog. |
| `church_tax_debit` | `CLT-LIAB-AVA` | `PLT-TAX-CHU` | Kirchensteuer analog. |
| `trading_fees` (Trader) | `CLT-LIAB-AVA` | `PLT-REV-ORD` *(default)* | Bei vorhandenem `feeBreakdown` werden mehrere Pairs geschrieben (s. ADR‑008). |

Nicht überlagert (bereits sauber):

- `investment_activate` / `investment_return` / `investment_refund` →
  GL‑Legs entstehen durch `investmentEscrow.bookDeployToTrading` /
  `bookReleaseTrading` / `bookReleaseReservation`. Ein zusätzliches Pair würde
  doppelt buchen.
- `trade_buy` / `trade_sell` (Trader) → bewusst **out of scope** für Phase 1.
  Eine vollständige Aktivposition (`CLT-AST-TRD`) erfordert Treuhand‑Bank‑Mapping
  (`BANK-TRT-CLT`) und ist für Phase 2 vorgesehen.

### `PLT-LIAB-COM` als Clearing‑Verbindlichkeit

Heute leitet `settleAndDistribute` 100 % der berechneten Provision an den Trader
weiter (`getTraderCommissionRate`). `PLT-LIAB-COM` saldiert in diesem Modell
**pro Trade auf 0**: Investor:in bucht ins Soll, Trader:in ins Haben. Sobald die
Plattform einen eigenen Anteil einführt, wird der App‑Cut additiv über
`PLT-REV-COM` als zusätzliches Haben gegen `PLT-LIAB-COM` geführt – ohne
Strukturänderung.

### Order‑Fees (`PLT-REV-ORD/EXC/FRG`)

Order‑Fee‑Erlöse werden ab sofort im `afterSave Invoice` (`invoiceType === 'order'`)
geschrieben, sodass `getAppLedger` sie nicht mehr über die
`entries.length === 0`‑Synthese ableiten muss. Der Synthese‑Pfad wird hinter ein
Feature‑Flag (`FIN1_LEDGER_LEGACY_FEE_SYNTHESIS`, default off) gelegt.

### Idempotenz / Backfill

- Idempotenz‑Schlüssel pro Pair: `(referenceId, referenceType, transactionType,
  metadata.leg)`. `metadata.leg` ist je `entryType` deterministisch (z. B.
  `commission`, `withholding_tax`, `order_fee:orderFee`).
- Backfill historischer `AccountStatement`‑Zeilen: separater Admin‑Cloud‑Job
  (out of scope dieser ADR; Skizze in PR4 / Roadmap).

### Out of scope (Phase 2+)

- `CLT-AST-TRD` / `CLT-AST-INV` (echte Mirror‑Asset‑Buchung).
- Treuhand‑Bankkonto `BANK-TRT-CLT` als Aktivseite zu `CLT-LIAB-AVA`.
- DATEV‑EXTF‑Export (PR3 hat den Mapping‑/Snapshot‑Unterbau bereits).
- Backfill bestehender Trades.

## Konsequenzen

### Positiv

- Vollständiger Buchungssatz für alle saldenwirksamen Settlement‑Vorfälle.
- USt‑/Quellensteuer‑Voranmeldung direkt aus `PLT-TAX-*` ableitbar.
- DATEV‑/SKR03‑Export wird belastbar (Erlös‑/Verbindlichkeitskonten enthalten
  Volumen).
- `Mirror`‑Trade Trader↔Pool ist über `PLT-LIAB-COM`‑Salden audithierbar.
- Reporting‑Hygiene: keine synthetischen Reads mehr im Default‑Pfad.

### Negativ / Risiken

- Schreiblast steigt um durchschnittlich 2 zusätzliche Parse‑Objekte pro
  `bookSettlementEntry`. `Parse.Object.saveAll` hält das in einem Roundtrip.
- Wenn ein GL‑Pair fehlschlägt, soll **die AccountStatement‑Zeile bestehen
  bleiben** (Fail‑Open, identisch zur bestehenden Beleg‑Strategie). Der Fehler
  wird geloggt; eine Operations‑Health‑Metrik („missing GL pair“) wird in PR4
  ergänzt.
- Strict‑Mapping (`FIN1_LEDGER_STRICT_MAPPING`) muss neue Konten kennen, sonst
  blockt es. Mapping wird in dieser ADR mitgepflegt.

### Migration

- Schema additiv (kein Migrationsskript): neue Konten landen im selben
  `AppLedgerEntry`‑Sammlerklasse.
- Default‑Verhalten bei Roll‑Back: alte `bookAccountStatementEntry`‑Aufrufe sind
  in `statements.js` weiterhin verfügbar.

## Referenzen

- `backend/parse-server/cloud/utils/accountingHelper/investmentEscrow.js`
- `backend/parse-server/cloud/utils/accountingHelper/settlement.js`
- `backend/parse-server/cloud/utils/accountingHelper/statements.js`
- `backend/parse-server/cloud/triggers/invoice/`
- `backend/parse-server/cloud/triggers/investment.js`
- `backend/parse-server/cloud/functions/admin/reports/appLedger.js`
- `backend/parse-server/cloud/utils/accountingHelper/accountMappingResolver.js`
- `Documentation/INVESTMENT_ESCROW_LEDGER_SKETCH.md` § 4 – Journal‑Sätze
- `Documentation/LEDGER_CHART_OF_ACCOUNTS_ROADMAP.md` (PR4)
- `Documentation/ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md` – Teil-Sell-Kennzahlen (iOS), Finance-Smoke, System-Health, App-Ledger-Aggregation / User-Filter (Ops)
