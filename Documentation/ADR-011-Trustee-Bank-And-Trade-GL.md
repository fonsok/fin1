# ADR-011 – Treuhand‑Bank `BANK-TRT-CLT` und GL‑Legs für Trade Buy/Sell + Wallet Deposit/Withdrawal

- Status: Proposed → Accepted (Phase 2 von ADR-010)
- Datum: 2026-04-29
- Author: Engineering / Accounting
- Bezug: `Documentation/ADR-010-Settlement-GL-Posting.md`,
  `Documentation/LEDGER_CHART_OF_ACCOUNTS_ROADMAP.md` (PR5),
  `Documentation/INVESTMENT_ESCROW_LEDGER_SKETCH.md` § 4

## Kontext

ADR-010 / PR4 hat das App‑Hauptbuch um Provisions‑, Steuer‑ und Order‑Fee‑Pairs
ergänzt. Drei AccountStatement‑Ereignisse blieben dabei bewusst **out of scope**
und erzeugen weiterhin nur Personenkonten‑Zeilen ohne GL‑Gegenbuchung:

- `trade_buy` (Trader: Wertpapierkauf)
- `trade_sell` (Trader: Wertpapierverkauf)
- `deposit` / `withdrawal` (Wallet‑Trigger)

Damit fehlt im Hauptbuch der Nachweis, dass Trader‑Cash (`CLT-LIAB-AVA`) und
das **Treuhand‑Bankkonto** korrekt gegeneinander laufen. Bei einem
Steuerprüfer‑Termin stünde der Cash‑Flow „Bank ↔ Kundenverbindlichkeit“ nur in
zwei voneinander unabhängigen Tabellen (`AccountStatement` vs.
`BankContraPosting`) — nicht in einem geschlossenen Buchungssatz.

## Entscheidung

Wir führen genau **ein** zusätzliches Hauptbuch‑Konto ein:

- `BANK-TRT-CLT` – Treuhand‑Bankkonto Kundengelder (SKR03 1230, „Bank Treuhand
  Kundengelder“, VAT 'frei', `taxTreatment: 'non_taxable'`).

Wertpapierbestand bleibt in dieser Phase **off‑balance‑sheet**: die Securities
liegen rechtlich beim Verwahrer und werden nicht als platform‑eigenes Aktivum
aktiviert. Eine spätere Erweiterung um `CLT-AST-SEC` / `CLT-LIAB-SEC` (mit
Sub‑Ledger pro User) ist in Phase 3 vorgesehen, sobald sie operativ benötigt
wird (z. B. für regulatorische Bestandsmeldungen).

### GL‑Mapping je `entryType` (additiv zur Tabelle aus ADR-010)

| `entryType` | Soll | Haben | Begründung |
| --- | --- | --- | --- |
| `trade_buy`  (Trader, amount < 0) | `CLT-LIAB-AVA` | `BANK-TRT-CLT` | Cash‑Claim Trader sinkt; Treuhand‑Bank zahlt an Broker. |
| `trade_sell` (Trader, amount > 0) | `BANK-TRT-CLT` | `CLT-LIAB-AVA` | Verkaufserlöse fließen ein; Cash‑Claim Trader steigt. |
| `deposit`     (Wallet, amount > 0) | `BANK-TRT-CLT` | `CLT-LIAB-AVA` | Bank‑Eingang, Cash‑Claim entsteht/erhöht sich. |
| `withdrawal`  (Wallet, amount < 0) | `CLT-LIAB-AVA` | `BANK-TRT-CLT` | Cash‑Claim sinkt, Bank zahlt aus. |

Beide Bewegungen ergeben pro Trade `Σdebit == Σcredit` über alle gebuchten
Pairs (Order‑Fees, Provision, Steuer, Trade‑Cash) und schließen die letzte
Lücke aus dem Friend‑Review.

### Schreibpfad

- `utils/accountingHelper/statements.js#bookSettlementEntry` erhält die neuen
  Rules in derselben Mapping‑Tabelle wie ADR-010.
- `utils/accountingHelper/settlement.js` schaltet die `trade_buy` /
  `trade_sell`‑Aufrufe von `bookAccountStatementEntry` auf
  `bookSettlementEntry` um — Logik bleibt unverändert, nur ein Funktionsname.
- `triggers/wallet.js` schaltet die `deposit` / `withdrawal`‑Aufrufe analog um.

### Securities Off‑Balance‑Sheet

Wir verzichten in Phase 2 bewusst auf `CLT-AST-SEC` / `CLT-LIAB-SEC`. Begründung:

- Der Wertpapierbestand liegt **rechtlich beim Verwahrer**, nicht auf einem
  platform‑eigenen Konto.
- Die Mirror‑Trade‑Allokation Trader↔Investor ist über
  `PoolTradeParticipation` + `Investment.profitBasis = 'mirror'` bereits
  technisch geschlossen.
- Eine vollwertige Securities‑Bestandsführung erfordert per‑User‑Sub‑Ledger
  (Position pro WKN pro User pro Zeitpunkt) und ein eigenes Reconciliation‑
  Tooling — das ist ein PR auf separater Komplexitätsebene und sollte erst
  begonnen werden, wenn aufsichtsrechtlich gefordert oder operativ nötig.

### Idempotenz

`postLedgerPair` benutzt weiterhin
`(referenceId, referenceType, transactionType, metadata.leg)`. Neue Legs:

- `trade_buy:cash`     – Trade‑BUY Cash‑Pair
- `trade_sell:cash`    – Trade‑SELL Cash‑Pair
- `wallet:deposit`     – Deposit‑Pair
- `wallet:withdrawal`  – Withdrawal‑Pair

Damit kann ein Replay sowohl auf Trade‑Ebene (`referenceId = tradeId`) als auch
auf Wallet‑Transaction‑Ebene (`referenceId = walletTxId`) eindeutig
short‑circuiten.

### Out of scope (Phase 3+)

- `CLT-AST-SEC` / `CLT-LIAB-SEC` (Securities‑Bestand pro User).
- Per‑Trade‑Reconciliation `BANK-TRT-CLT` ↔ tatsächlicher Bankauszug.
- Backfill historischer `trade_buy` / `trade_sell` / `deposit` / `withdrawal`
  Pairs (separater Admin‑Job, geplant in Phase 3).

## Konsequenzen

### Positiv

- Vollständiger Cash‑Flow im Hauptbuch: Treuhand‑Bank ↔ Kundenverbindlichkeit
  ↔ Plattform‑Erlöse / FA‑Verbindlichkeiten.
- Pro Trade lückenlos verkettete Buchungssätze (Order‑Fees, Provision, Steuer,
  Cash) — DATEV‑Übergabe wird inhaltlich vollständig.
- Trader↔Pool‑Mirror‑Klammer bleibt über `PLT-LIAB-COM` saldenneutral; der
  Cash‑Schritt wird zusätzlich über `BANK-TRT-CLT` traceable.

### Negativ / Risiken

- Eine zusätzliche `Parse.Object.saveAll`‑Operation pro Trade‑Order und pro
  Wallet‑Tx (zwei `AppLedgerEntry`‑Rows). In einem `saveAll` zusammengefasst,
  damit kein zusätzlicher Roundtrip.
- `BANK-TRT-CLT` wird in dieser Phase noch **nicht** mit dem realen
  Bankauszug abgeglichen — dafür gibt es schon `BankContraPosting`.

### Migration

- Schema additiv (kein Migrationsskript).
- Strict‑Mapping (`FIN1_LEDGER_STRICT_MAPPING`): das neue Konto ist im Resolver
  registriert, Strict bleibt grün.
- Kein Rückwirkungs‑Backfill in dieser ADR (separater PR6).

## Referenzen

- `backend/parse-server/cloud/utils/accountingHelper/journal.js`
- `backend/parse-server/cloud/utils/accountingHelper/statements.js`
- `backend/parse-server/cloud/utils/accountingHelper/settlement.js`
- `backend/parse-server/cloud/utils/accountingHelper/accountMappingResolver.js`
- `backend/parse-server/cloud/triggers/wallet.js`
- `Documentation/ADR-010-Settlement-GL-Posting.md`
- `Documentation/ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md` — Teil-Sell-Kennzahlen (iOS), Finance-Smoke, System-Health, App-Ledger-Aggregation (Ops)
- `Documentation/INVESTMENT_ESCROW_LEDGER_SKETCH.md`
