# DRY Violation: Return Percentage Calculation

## Status: ✅ FIXED

**Implementation Date**: Current session
**Solution**: Shared utility function in `ProfitCalculationService.calculateReturnPercentage()`

## Problem Statement

The return percentage calculation was duplicated in multiple places, violating the DRY (Don't Repeat Yourself) principle and the "single source of truth" rule.

## Current Violations

### 1. InvestmentCompletionService.swift (Line 102)
```swift
calculatedReturn = investorTotals.investedAmount > 0 ?
    (investorTotals.grossProfit / investorTotals.investedAmount) : 0.0
```
- **Purpose**: Calculates and stores `investment.performance`
- **Used by**: Completed Investments table (reads `investment.performance`)

### 2. InvestmentCompletionService.swift (Line 171)
```swift
let returnPercentage = investorTotals.investedAmount > 0 ?
    (investorTotals.grossProfit / investorTotals.investedAmount) * 100 : 0.0
```
- **Purpose**: Updates investment performance during profit updates
- **Note**: Multiplies by 100 (stores as percentage)

### 3. InvestorInvestmentStatementView.swift (Line 174)
```swift
let grossProfitPercentage = (item.grossProfit / item.roiInvestedAmount) * 100
```
- **Purpose**: Calculates percentage on-the-fly for Collection Bill display
- **Used by**: Collection Bill view (per-trade item display)

## Issues

1. **Code Duplication**: Same formula repeated in 3 places
2. **Inconsistency Risk**: Different calculation methods could diverge over time
3. **Maintenance Burden**: Changes must be made in multiple places
4. **Rounding Differences**: Slight differences (e.g., 98.06% vs 98.05%) due to:
   - Different data sources (aggregate vs per-trade)
   - Rounding in intermediate calculations
   - Different calculation paths

## Root Cause

- **InvestmentCompletionService** uses `calculateInvestorTotals()` which aggregates across all trades
- **Collection Bill** uses `InvestorCollectionBillCalculationService` which calculates per-trade
- Both should use the same underlying calculation method, but they're using different aggregation approaches

## Solution

### Option 1: Extract to Shared Utility (Recommended)

Add a utility function to `ProfitCalculationService` or create a new `ReturnCalculationService`:

```swift
// In ProfitCalculationService or new ReturnCalculationService
static func calculateReturnPercentage(
    grossProfit: Double,
    investedAmount: Double
) -> Double? {
    guard investedAmount > 0 else { return nil }
    return (grossProfit / investedAmount) * 100
}
```

**Benefits**:
- Single source of truth for calculation
- Consistent rounding behavior
- Easier to test and maintain
- Clear documentation of formula

### Option 2: Use Statement Summary Aggregate Values

For single-trade investments, the Collection Bill could use the aggregate percentage from `InvestorInvestmentStatementSummary` instead of calculating per-trade.

**Benefits**:
- Matches Completed Investments table exactly
- Uses same aggregation method

**Drawbacks**:
- Only works for single-trade investments
- Still need per-trade percentages for multi-trade investments

### Option 3: Store Percentage in Statement Item

Calculate percentage once during statement item creation and store it.

**Benefits**:
- Calculated once, used everywhere
- Consistent values

**Drawbacks**:
- Adds field to data model
- Still need aggregate calculation for multi-trade

## Implementation (✅ COMPLETED)

### Solution: Shared Utility Function

**File**: `FIN1/Shared/Services/ProfitCalculationService.swift`

Added new method:
```swift
static func calculateReturnPercentage(
    grossProfit: Double,
    investedAmount: Double
) -> Double? {
    guard investedAmount > 0 else { return nil }
    return (grossProfit / investedAmount) * 100
}
```

### Updated Files

1. **`FIN1/Features/Trader/Models/Trade.swift`**
   - Updated `roi` computed property to use shared function
   - Before: `return (pnl / totalBuyCost) * 100`
   - After: `return ProfitCalculationService.calculateReturnPercentage(grossProfit: pnl, investedAmount: totalBuyCost)`

2. **`FIN1/Features/Investor/Services/InvestmentCompletionService.swift`** (2 locations)
   - Line 102: Updated `calculatedReturn` calculation
   - Line 171: Updated `returnPercentage` calculation
   - Both now use shared function

3. **`FIN1/Features/Investor/Views/Components/InvestorInvestmentStatementView.swift`**
   - Updated Collection Bill percentage display
   - Now uses shared function for consistency

## Impact

- **Before**: 4 places calculating percentage (potential for divergence)
- **After**: 1 shared utility function (single source of truth)
- **Result**: Consistent percentages across all views (trader and investor)
- **Benefits**:
  - ✅ Single source of truth
  - ✅ Consistent rounding behavior
  - ✅ Easier to test and maintain
  - ✅ Clear documentation of formula
  - ✅ Eliminates potential for divergence

## Trader Side Analysis

### Trader ROI Calculation

**Location**: ```185:192:FIN1/Features/Trader/Models/Trade.swift```

```swift
var roi: Double? {
    guard let pnl = currentPnL, totalSoldQuantity > 0 else { return nil }
    let totalBuyCost = buyOrder.price * totalSoldQuantity
    return (pnl / totalBuyCost) * 100
}
```

**Formula**: `(currentPnL / (buyOrder.price * totalSoldQuantity)) * 100`

**Status**: ✅ **NO DRY VIOLATION** on trader side
- Single calculation point in `Trade.roi` computed property
- Views just display `trade.returnPercentage` (which comes from `Trade.roi`)
- `TradesOverviewViewModel` uses `trade.roi ?? 0` (line 78) - no recalculation
- `TradeDetailsViewModel` displays `trade.returnPercentage` (line 31) - no recalculation

### Trader vs Investor Formula Comparison

**Trader Formula**:
```swift
(pnl / (buyOrder.price * totalSoldQuantity)) * 100
```

**Investor Formula**:
```swift
(grossProfit / ((buyOrder.price * totalSoldQuantity) * ownershipPercentage)) * 100
```

**Mathematical Equivalence**:
- When `ownershipPercentage = 1.0` (full ownership), formulas are equivalent
- Both use same numerator calculation method (invoice-based profit)
- Both use same denominator base (`buyOrder.price * totalSoldQuantity`)
- Investor formula scales denominator by ownership percentage

**Conclusion**: While trader side has no DRY violation, both trader and investor could benefit from a shared utility function to ensure:
1. Consistent formula structure
2. Same rounding behavior
3. Easier maintenance if formula needs to change

## Recommended Solution (Unified)

Create a shared utility function that works for both trader and investor:

```swift
// In ProfitCalculationService or new ReturnCalculationService
static func calculateReturnPercentage(
    grossProfit: Double,
    investedAmount: Double
) -> Double? {
    guard investedAmount > 0 else { return nil }
    return (grossProfit / investedAmount) * 100
}

// For trader (ownershipPercentage = 1.0):
let traderROI = calculateReturnPercentage(
    grossProfit: pnl,
    investedAmount: buyOrder.price * totalSoldQuantity
)

// For investor (scaled by ownership):
let investorROI = calculateReturnPercentage(
    grossProfit: grossProfit,
    investedAmount: (buyOrder.price * totalSoldQuantity) * ownershipPercentage
)
```

**Benefits**:
- ✅ Single source of truth for calculation formula
- ✅ Consistent rounding behavior across trader and investor
- ✅ Easier to test and maintain
- ✅ Clear documentation of formula
- ✅ Eliminates potential for divergence

## Related Files

- `FIN1/Features/Trader/Models/Trade.swift` (trader ROI calculation)
- `FIN1/Features/Investor/Services/InvestmentCompletionService.swift` (investor return calculation)
- `FIN1/Features/Investor/Views/Components/InvestorInvestmentStatementView.swift` (investor display calculation)
- `FIN1/Shared/Services/ProfitCalculationService.swift` (profit calculations)
- `FIN1/Features/Investor/Services/InvestorInvestmentStatementAggregator.swift` (aggregation)

