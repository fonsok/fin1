# Investor Calculation Logic (Live Implementation)

Scope: Investor-specific calculations for buy/sell legs, profit, ROI bases, commission, and per-investment statements. Reflects current code paths.

## Consumer API Reference
- Collection bill (single participation): `InvestorCollectionBillCalculationService.calculateCollectionBill(input:) -> InvestorCollectionBillOutput`
- Validation only: `validateInput(_:) -> ValidationResult`
- Investor totals across trades: `InvestmentProfitCalculator.calculateInvestorTotals(...) -> (grossProfit, investedAmount)?`
- Investor gross profit (async service): `InvestorGrossProfitService.getGrossProfit(for:tradeId:) -> Double`, `getGrossProfitsForTrade(tradeId:) -> [investmentId: Double]`
- Commission: `CommissionCalculationService.calculateCommission(grossProfit:rate:)`, `calculateNetProfitAfterCommission`, `calculateCommissionAndNetProfit`, `calculateCommissionForInvestor`, `calculateTotalCommissionForTrade`
- Statement aggregation: `InvestorInvestmentStatementAggregator.summarizeInvestment(...) -> InvestorInvestmentStatementSummary?`
- Per-investment UI: `InvestorInvestmentStatementViewModel` (constructor builds immediately; `rebuildStatement()`)

### Inputs/Outputs & Preconditions
- Collection bill input: `investmentCapital` (source of truth, must be >0), `buyPrice` >0, `tradeTotalQuantity` >0, `ownershipPercentage` (0–1], invoices optional but used for fees/sell prices, `investorAllocatedAmount` optional.
- Output includes buy amount/quantity/fees/details, sell amount/quantity/avg price/fees, residual, grossProfit, roiGrossProfit, roiInvestedAmount.
- Totals require `potTradeParticipationService`, `tradeLifecycleService`, `invoiceService`, optional `investmentCapital` and `InvestorCollectionBillCalculationService`.
- Gross profit service needs aggregation via statement items; returns error if missing data.
- Commission uses `CalculationConstants.FeeRates.traderCommissionRate` by default.

## Porting Checklist
- Buy leg math: solve buyAmount + fees(buyAmount) = investmentCapital; round quantity down; recompute fees; residual handling; clamp to capital.
- Sell leg math: ownership-scaled quantities/prices from sell invoices; fees via same fee service; provide breakdown.
- Profit/ROI bases: gross profit = (sell + sell fees) − (buy + buy fees); track ROI invested amount (buy securities value) and ROI gross profit separately.
- Capital allocation across trades: single trade = full capital; multi-trade proportional by ownership% (fallback even split if no ownership sum).
- Fallbacks: if calc fails, invoice-based proportional profit; legacy denominator handling.
- Commission: compute once from total gross profit; ensure zeroed when gross ≤ 0.
- Validation: enforce positive inputs and ownership bounds; warn on invoice qty vs calculated qty differences; ensure required invoices exist for statements.
- Data contracts: `InvestorCollectionBillInput/Output`, `InvestorInvestmentStatementItem/Summary`, `ValidationResult`, `InvestorFeeDetail`.


## Collection Bill Calculations
- Source: `FIN1/Features/Investor/Services/InvestorCollectionBillCalculationService.swift`
- Input validation: positive capital/price/ownership/trade quantity; warns on invoice quantity mismatch vs calculated quantity.
- Buy leg:
  - Solves for buyAmount such that `buyAmount + fees(buyAmount) = investmentCapital` (fees via `FeeCalculationService`), using binary search with cent tolerance.
  - Rounds quantity down to whole units; recalculates fees based on rounded amount.
  - Ensures total buy cost ≤ investment capital; computes residual (unused capital); warns and can adjust if residual could buy one more unit.
  - Provides fee details with percentage rates.
- Sell leg:
  - Uses sell invoices and ownership percentage to compute sell amount/quantity/avg price.
  - Calculates fees via `FeeCalculationService` and provides detailed breakdown.
- Profit & ROI bases:
  - Gross profit = (sell amount + sell fees) − (buy amount + buy fees); ROI gross profit and invested amount tracked separately.
  - Output includes buy/sell amounts, quantities, fees, residual, gross profit, ROI fields.

## Investment Totals & ROI Aggregation
- Source: `FIN1/Features/Investor/Services/InvestmentProfitCalculator.swift`
- For each participation, splits investment capital across trades (single trade = full capital; multi-trade proportional by ownership% or even split fallback).
- For each trade: builds `InvestorCollectionBillInput`, runs `calculateCollectionBill`, sums gross profit and total buy cost (securities + fees) as invested amount.
- ROI: uses trade ROI weighting when available; fallback ROI from aggregated gross profit / invested amount.
- Fallbacks: if collection-bill calc fails, uses invoice-based `calculateInvestorTaxableProfit` and legacy denominators.

## Investor Gross Profit Service
- Source: `FIN1/Shared/Services/InvestorGrossProfitService.swift`
- Single source of truth for investor gross profit per trade/investment; pulls statement aggregation via `InvestorInvestmentStatementAggregator`.
- Exposes async APIs used by commission calculation and other consumers; validates coverage and logs missing investments.

## Commission Calculation
- Source: `FIN1/Shared/Services/CommissionCalculationService.swift`
- Basic commission: rate × gross profit (floored at zero), net profit = gross − commission.
- Investor/trade totals: fetches investor gross profits via `InvestorGrossProfitService`, sums commissions per trade; logs and handles partial data.

## Investment Statement Aggregation
- Source: `FIN1/Features/Investor/Services/InvestorInvestmentStatementAggregator.swift`
- For an investment:
  - Retrieves participations and investment capital (source of truth).
  - For each trade: fetches buy/sell invoices; allocates capital share (ownership-weighted if multiple trades); builds statement item via `InvestorInvestmentStatementItem.build` using `InvestorCollectionBillCalculationService`.
  - Sums: gross profit, buy amounts (securities), buy fees, total buy cost, residual, sell amounts, sell fees (negative), net sell amount, ROI gross profit/invested amount.
  - Commission: calculated once from total gross profit using `CalculationConstants.FeeRates.traderCommissionRate`.
  - Returns sorted items and summary totals; fails if any trade is missing required invoices.

## Per-Investment Statement ViewModel
- Source: `FIN1/Features/Investor/ViewModels/InvestorInvestmentStatementViewModel.swift`
- Builds UI statement items per participation using the same collection-bill calculation; splits investment capital across trades; relies on `InvestorCollectionBillCalculationService` to ensure parity with collection bill and investor summaries.


