# Account Statements and Monthly Reports (Live Implementation)

Scope: How account statements, monthly documents, and per-investment statements are produced today for traders and investors.

## Consumer API Reference
- Monthly statement generation: `MonthlyAccountStatementGenerator.ensureMonthlyStatements(for:services:)` (async), `createMockCurrentMonthStatement(for:services:)` (async)
- Account statements (UI):
  - `AccountStatementViewModel.refresh()` builds entries/balances for current user (investor/trader) and applies filters.
  - `MonthlyAccountStatementViewModel.load()` builds entries/balances for a specific year/month.
- Trader ledger snapshot: `TraderAccountStatementBuilder.buildSnapshot(for:invoiceService:configurationService:) -> TraderAccountStatementSnapshot`
- Investment statements: `InvestorInvestmentStatementAggregator.summarizeInvestment(...) -> InvestorInvestmentStatementSummary?`

### Inputs/Outputs & Preconditions
- Monthly generator: needs `user` with role, `AppServices` (investor cash balance service, invoice service, configuration, document, notification). Skips if no entries; skips current month; requires statements not already existing.
- AccountStatementViewModel: needs current user, investor cash balance service, invoice service, configuration service, optional traderDataService; ranges filter via `selectedRange.startDate()`.
- MonthlyAccountStatementViewModel: needs current user, same services; computes base opening balance (investor: closing − total delta; trader: snapshot.opening); slices entries to month.
- Trader snapshot: requires invoices reachable by customer IDs (customerId, fallback list), configuration initial balance; handles trade invoices and credit-note commissions.
- Investment statement aggregator: requires participations, trade lifecycle, invoices, investment (or service), calculation service; fails if missing buy/sell invoices or trades.

## Porting Checklist
- Monthly generation: month grouping (year-month), skip current month; create document records with statement year/month/role; notify user; ensure non-zero placeholder size; validate before upload.
- Trader ledger: opening balance from config; running balance through invoices; treat sells as credits, buys as debits; parse commission credit notes; enrich metadata (trade number, WKN/ISIN, direction, underlying, strike, issuer, quantity).
- Investor ledger: use cash ledger from investorCashBalanceService; opening = closing − total delta; sort descending.
- Balances per month: opening = base opening + pre-month delta; closing = opening + month delta; entries filtered to month window.
- Filters: date-based filtering for ranges; expose totals (credits, debits, net change).
- Investment statements: aggregate via collection-bill-backed items; sum gross profit, buy/sell amounts, fees, residuals, net sell amount, ROI bases, commission; require all invoices present.
- Document naming: month/year, role-aware; avoid duplicates; mock generator for current month for manual needs.


## Monthly Account Statement Generation
- Source: `FIN1/Shared/Services/MonthlyAccountStatementGenerator.swift`
- Builds all completed-month statements (skips current month) for the current user role:
  - Investor: uses `investorCashBalanceService.getTransactions`.
  - Trader: uses `TraderAccountStatementBuilder.buildSnapshot` (invoices-derived ledger).
- Groups entries by year-month, skips months with no entries or existing documents.
- Creates document records (placeholder file URLs/size), validates with `documentService`, uploads, and sends notifications.
- Supports mock current-month statement generation for manual creation, using current transactions.

## Account Statement ViewModels (UI)
- Source: `FIN1/Features/Dashboard/ViewModels/AccountStatementViewModel.swift`
- Fetches statements per role:
  - Investor: ledger from `investorCashBalanceService`, opening balance = closing balance − total delta; entries sorted descending.
  - Trader: snapshot from `TraderAccountStatementBuilder` (opening/closing balances + entries).
- Filters entries by selected range; exposes totals (credits, debits, net change).

- Source: `FIN1/Features/Dashboard/ViewModels/MonthlyAccountStatementViewModel.swift`
- For a given year/month:
  - Investor: ledger + current balance from `investorCashBalanceService`; derives base opening balance from closing − total delta.
  - Trader: uses `TraderAccountStatementBuilder` snapshot for entries and opening balance.
  - Computes opening/closing balances for the month by summing deltas before and within the month; slices entries to the month window.
- Provides header labels (title, period, opening balance date) and mock account identifiers.

## Trader Ledger Construction
- Source: `FIN1/Shared/Accounting/TraderAccountStatementBuilder.swift`
- Opening balance from `configurationService.initialAccountBalance`.
- Reads invoices (buy/sell and credit-note commissions), sorted by createdAt, and produces `AccountStatementEntry` with running balance:
  - Credit notes: treated as credits (commissions), parses trade numbers into metadata.
  - Trades: direction by transaction type (sell = credit, buy = debit), amount = `invoice.totalAmount`, reference from tradeId/invoice number, metadata enriched with trade/securities details when present.
- Returns entries plus opening/closing balances.

## Investor Investment Statements
- Source: `FIN1/Features/Investor/Services/InvestorInvestmentStatementAggregator.swift`
- Aggregates per-investment statement items (built via `InvestorInvestmentStatementItem.build` and `InvestorCollectionBillCalculationService`), summing gross profit, buy/sell amounts, fees, residuals, ROI bases, and commission; validates presence of invoices and trades.
- Consumed by `InvestorInvestmentStatementViewModel` to present per-investment breakdowns consistent with collection bill and investor profit calculations.


