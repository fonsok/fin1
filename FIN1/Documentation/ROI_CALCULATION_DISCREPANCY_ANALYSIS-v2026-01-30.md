# ROI Calculation Discrepancy Analysis: Trader vs Investor

## Problem Statement

Completed trades show **112%** return in the trader view, while completed investments show **114.46%** return in the investor view for the same underlying trade. This discrepancy raises questions about calculation consistency.

## Root Cause Analysis

### Trader ROI Calculation

**Location**: ```185:189:FIN1/Features/Trader/Models/Trade.swift```

```swift
var roi: Double? {
    guard let pnl = currentPnL, totalSoldQuantity > 0 else { return nil }
    let totalBuyCost = buyOrder.price * totalSoldQuantity
    return (pnl / totalBuyCost) * 100
}
```

**Formula**: `(currentPnL / (buyOrder.price * totalSoldQuantity)) * 100`

**Components**:
- **Numerator (`currentPnL`)**:
  - Uses `calculatedProfit` from invoices (```152:152:FIN1/Features/Trader/Services/TradeLifecycleService.swift```)
  - Calculated via `ProfitCalculationService.calculateTaxableProfit()` (```22:38:FIN1/Shared/Services/ProfitCalculationService.swift```)
  - Formula: `totalSellAmount - totalBuyAmount` where amounts use `invoice.nonTaxTotal` (includes fees)
  - **Includes fees in the profit calculation**
- **Denominator**: `buyOrder.price * totalSoldQuantity` (pure securities value of SOLD quantity)

### Investor Return Calculation

**Location**: ```102:102:FIN1/Features/Investor/Services/InvestmentCompletionService.swift```

```swift
calculatedReturn = investorTotals.investedAmount > 0 ?
    (investorTotals.grossProfit / investorTotals.investedAmount) : 0.0
```

**Formula**: `(grossProfit / investedAmount) * 100`

**Components**:
- **Numerator (`grossProfit`)**:
  - From `statementItem.grossProfit` (```145:145:FIN1/Features/Investor/ViewModels/InvestorInvestmentStatementViewModel.swift```)
  - Formula: `investorSellValue - investorSellFees - (buyTotal + buyFeesInvestor)`
  - **Includes fees in the profit calculation**
- **Denominator (`investedAmount`)**:
  - From `soldSecuritiesValue` = `statementItem.buyPrice * statementItem.sellQuantity` (```295:295:FIN1/Features/Investor/Services/InvestmentCompletionService.swift```)
  - Pure securities value of SOLD quantity

## Key Differences

### 1. Profit Calculation Method

**Trader**: Uses invoice-based calculation (`calculateTaxableProfit`)
- Uses `invoice.nonTaxTotal` which includes fees
- Formula: `sellInvoices.nonTaxTotal - buyInvoices.nonTaxTotal`

**Investor**: Uses order-based calculation with explicit fee subtraction
- Formula: `investorSellValue - investorSellFees - (buyTotal + buyFeesInvestor)`
- Manually subtracts fees from sell value and adds fees to buy cost

### 2. Fee Handling

Both calculations include fees, but:
- **Trader**: Fees are embedded in `nonTaxTotal` (invoice-level aggregation)
- **Investor**: Fees are explicitly calculated and subtracted/added

### 3. Proportional Scaling

**Investor calculation** scales everything proportionally:
- `investorSellValue` = scaled by ownership percentage
- `investorSellFees` = scaled by sell share
- `buyTotal` = scaled by ownership percentage
- `buyFeesInvestor` = scaled by ownership percentage

**Trader calculation** uses full trade values (no scaling needed).

## Why the Discrepancy Occurs

The discrepancy (112% vs 114.46%) likely occurs due to:

1. **Rounding differences** in fee calculations when scaling proportionally
2. **Different calculation paths**: Invoice-based (trader) vs Order-based with explicit fee handling (investor)
3. **Fee calculation timing**: Trader uses pre-calculated invoice totals, investor recalculates fees proportionally

### Example Scenario

Assuming a trade with:
- Buy: 1,000 pieces @ €2.00 = €2,000
- Fees: €83.00 (calculated on total order)
- Sell: 1,000 pieces @ €4.50 = €4,500
- Fees: €83.00

**Trader ROI**:
- Profit: €4,500 - €83 - (€2,000 + €83) = €2,334
- Denominator: €2,000 (securities value)
- ROI: (€2,334 / €2,000) × 100 = **116.7%**

**Investor ROI** (assuming 50% ownership):
- Investor sell value: €2,250 (50% of €4,500)
- Investor sell fees: €41.50 (50% of €83)
- Investor buy total: €1,000 (50% of €2,000)
- Investor buy fees: €41.50 (50% of €83)
- Profit: €2,250 - €41.50 - (€1,000 + €41.50) = €1,167
- Denominator: €1,000 (securities value)
- ROI: (€1,167 / €1,000) × 100 = **116.7%**

**The calculations should match**, but rounding in fee calculations can cause small discrepancies.

## Potential Issues

### Issue 1: Fee Proportionality

When fees are split proportionally, rounding can cause:
- Total of proportional fees ≠ Original total fees
- This creates small discrepancies in profit calculations

### Issue 2: Calculation Path Inconsistency

- **Trader**: Uses invoice `nonTaxTotal` (aggregated, may have rounding)
- **Investor**: Recalculates fees proportionally (may have different rounding)

### Issue 3: Denominator Base

Both use securities value, but:
- Trader: `buyOrder.price * totalSoldQuantity` (from order)
- Investor: `buyPrice * sellQuantity` (from statement item, may be recalculated)

## Recommendations

### 1. Use Single Calculation Source

Both trader and investor should use the **same profit calculation method**:
- Option A: Both use invoice-based calculation (`calculateTaxableProfit`)
- Option B: Both use order-based calculation with explicit fee handling

### 2. Standardize Fee Calculation

Ensure fees are calculated identically:
- Use the same fee calculation service
- Apply same rounding rules
- Verify proportional fee splits sum to total

### 3. Add Validation

Add unit tests that verify:
- Trader ROI and Investor Return match for the same trade
- Proportional calculations sum correctly
- Fee calculations are consistent

### 4. Use Same Denominator Base

Ensure both calculations use the same source for:
- Buy price
- Sold quantity
- Securities value

## Current Status

The discrepancy is likely due to:
1. **Rounding differences** in proportional fee calculations
2. **Calculation path differences** (invoice-based vs order-based)
3. **Small numerical precision differences**

The calculations are **conceptually correct** but may have **implementation inconsistencies** that cause small discrepancies.

## Code References

- Trader ROI: ```185:189:FIN1/Features/Trader/Models/Trade.swift```
- Investor Return: ```102:102:FIN1/Features/Investor/Services/InvestmentCompletionService.swift```
- Profit Calculation: ```22:38:FIN1/Shared/Services/ProfitCalculationService.swift```
- Investor Statement: ```102:169:FIN1/Features/Investor/ViewModels/InvestorInvestmentStatementViewModel.swift```


