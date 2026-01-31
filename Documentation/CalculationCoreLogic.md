# Calculation Core Logic (Live Implementation)

Scope: The active calculation surfaces that produce profits, fees, quantities, taxes, and guarded consistency in the app. This documents what the code does today (not future intent).

## Consumer API Reference (what you can call)
- Profit (invoice-based): `ProfitCalculationService.calculateTaxableProfit(buyInvoice:sellInvoices:) -> Double`
- Net cashflow (incl. taxes): `ProfitCalculationService.calculateNetCashFlow(buyInvoice:sellInvoices:) -> Double`
- Gross profit (order-based): `ProfitCalculationService.calculateGrossProfitFromOrders(for trade: Trade) -> Double`
- Investor proportional profit: `ProfitCalculationService.calculateInvestorTaxableProfit(buyInvoice:sellInvoices:ownershipPercentage:) -> Double`
- ROI %: `ProfitCalculationService.calculateReturnPercentage(grossProfit:investedAmount:) -> Double?`
- Fees: `FeeCalculationService.calculateTotalFees(for orderAmount: Double) -> Double`; `createFeeBreakdown(for:) -> [FeeDetail]`
- Guards: `CalculationGuardService.guardProfitCalculation`, `guardTaxCalculation`, `guardFeeCalculation`, `guardInvoiceFiltering`, `guardCompleteCalculation`
- Trade breakdown: `TradeCalculationService.calculateTradeBreakdown(for:buyInvoice:sellInvoices:) -> TransactionBreakdown`
- Quantity: `InvestmentQuantityCalculationService.calculateMaxPurchasableQuantity(...) -> Int`; `calculateCombinedOrderDetails(...) -> CombinedOrderCalculationResult`
- Securities value: `SecuritiesValueCalculator.calculateMaxSecuritiesValue(...) -> Double`

### Inputs/Outputs & Preconditions
- Invoices: expect `transactionType` (.buy/.sell), `nonTaxTotal`, `totalAmount`, `items` typed by `.securities/.tax/.orderFee/.exchangeFee/.foreignCosts/.commission`.
- Trades: need `buyOrder`, optional `sellOrders`/`sellOrder`, quantities/prices, `totalQuantity`, `displayROI`.
- Fee constants: from `CalculationConstants.FeeRates` (order fee %, min €5/max €50; exchange fee %, min €1/max €20; foreign €1.50).
- Guards: validationMode can be strict/warning/disabled; fatalError on strict mismatch.

## Porting Checklist (what to replicate)
- Profit math: invoice-based profit uses `nonTaxTotal` and filters by transaction type; return% uses grossProfit / investedAmount.
- Fees: same rate/cap constants and breakdown naming; foreign costs fixed.
- Order-based profit: buy = price×qty + fees; sell = price×qty − fees per order; gross = sellNet − buyTotal.
- Quantity search: binary/denomination search must include fees in affordability; combined order splits fees proportionally by order amounts.
- Guards: enforce canonical paths and item filtering; ensure tax calculation uses `InvoiceTaxCalculator` equivalent.
- Data contracts: TransactionDetails/FeeDetail shapes; CalculationConstants parity.


## Profit & Return Calculations
- Source: `FIN1/Shared/Services/ProfitCalculationService.swift`
- Invoice-based profit: `calculateTaxableProfit(buyInvoice:sellInvoices:)` uses `invoice.nonTaxTotal`, filters by transaction type, and returns `totalSellAmount - totalBuyAmount`.
- Net cashflow: `calculateNetCashFlow(buyInvoice:sellInvoices:)` includes taxes (`invoice.totalAmount`), sells positive, buys negative.
- Order-based gross profit: `calculateGrossProfitFromOrders(for:)` computes buy securities value + fees, sell securities value − fees (per order), then `sellNetProceeds - buyTotalCost`; uses `FeeCalculationService`.
- Investor proportional profit: `calculateInvestorTaxableProfit` scales invoice-based profit by ownership percentage (keeps trader/investor parity).
- ROI percentage: `calculateReturnPercentage(grossProfit:investedAmount:)` returns `(grossProfit / investedAmount) * 100`, nil if investedAmount ≤ 0.

## Fee Calculations
- Source: `FIN1/Shared/Services/FeeCalculationService.swift`
- Total fees: `calculateTotalFees(orderAmount)` = order fee (0.5%, min €5, max €50) + exchange fee (0.1%, min €1, max €20) + foreign costs (€1.50).
- Breakdown: `createFeeBreakdown(orderAmount)` returns named components; used across calculators to ensure identical fee math.

## Calculation Guardrails
- Source: `FIN1/Shared/Services/CalculationGuardService.swift`
- Guards profit/tax/fee calls to the canonical methods; optional validation/fallback comparison.
- Invoice filtering: Filters items by calculation type (profit excludes tax items; tax only tax items; fee only fee items; securities only securities items).
- Composite guard: `guardCompleteCalculation` runs profit → tax total → individual taxes → net result.

## Trade Breakdown (Trader)
- Source: `FIN1/Features/Trader/Services/TradeCalculationService.swift`
- Builds buy/sell `TransactionDetails` from invoices (matches sell orders to invoices), computes subtotals with fee breakdowns, then profit-before-tax via `ProfitCalculationService`.
- Taxes: uses `InvoiceTaxCalculator` per component and `CalculationGuardService.guardTaxCalculation` for the total.
- Net result: profit-before-tax − total taxes; returns structured `TransactionBreakdown`.

## Quantity / Capital Utilization
- Source: `FIN1/Shared/Services/InvestmentQuantityCalculationService.swift`
- Calculates max purchasable quantity given balance, price, denomination, subscription ratio, minimum order amount:
  - Binary search (or denomination-stepped search) over quantities.
  - Uses `FeeCalculationService.calculateTotalFees` to include fees in affordability.
- Combined trader+investment order: maximizes both trader cash and pool capital; splits fees proportionally by order amounts; computes totals, residuals, remaining balances, shares.

- Source: `FIN1/Features/Trader/Services/SecuritiesValueCalculator.swift`
- Pure helper to maximize securities value from capital with fees/denominations via binary or stepped search; logs utilization; also relies on `FeeCalculationService`.

## Supporting Models / Constants
- `TransactionDetails` and `FeeDetail` structs live in `ProfitCalculationService`.
- Fee thresholds and rates come from `CalculationConstants.FeeRates`.


