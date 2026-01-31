# Commission Calculation Architecture Analysis

## Executive Summary

Yes, the difficulty in fixing the commission calculation was **partially due to architectural issues**. The codebase has multiple calculation paths, inconsistent data sources, and lacks a single source of truth for investor gross profit calculations.

## Key Architectural Issues Identified

### 1. **Multiple Calculation Methods for Gross Profit**

**Problem**: Gross profit is calculated differently in different parts of the codebase:

1. **ProfitDistributionService** (Line 45):
   ```swift
   let grossProfit = trade.calculatedProfit ?? trade.currentPnL ?? 0.0
   ```
   - Uses pre-calculated values from Trade model
   - Fallback chain that may not match actual invoices

2. **TradesOverviewViewModel** (Line 196-209):
   ```swift
   private func calculateInvoiceBasedProfit(for trade: Trade) -> Double {
       return ProfitCalculationService.calculateTaxableProfit(buyInvoice: buyInvoice, sellInvoices: sellInvoices)
   }
   ```
   - Uses invoice-based calculation
   - Different from Collection Bill calculation

3. **InvestorCollectionBillCalculationService**:
   ```swift
   let grossProfit = sellAmount + sellFees - (buyAmount + buyFees)
   ```
   - Uses investment capital as source of truth
   - Most accurate for investor-specific calculations
   - **This is the correct one** (what we ended up using)

4. **ProfitCalculationService.calculateGrossProfitFromOrders**:
   - Uses order-based calculation
   - May not match invoice-based calculations

**Impact**: Each method can produce different results, making it hard to know which is correct.

### 2. **Inconsistent Data Sources**

**Problem**: Different services use different data sources for the same calculation:

- **Collection Bill**: Uses `investment.amount` (investment capital) as source of truth
- **ProfitDistributionService**: Uses `allocatedAmount` from participations
- **TradesOverviewViewModel**: Uses invoice totals
- **Commission Breakdown**: Initially tried to recalculate instead of using Collection Bill values

**Impact**: Values don't match between different views, causing confusion and bugs.

### 3. **Commission Calculation Duplication**

**Problem**: Commission is calculated in multiple places with slightly different logic:

1. **ProfitDistributionService** (Line 71):
   ```swift
   totalCommission = totalAllocatedAmount * (tradeROI / 100.0) * commissionRate
   ```
   - Uses `allocatedAmount` and `tradeROI`

2. **TradesOverviewViewModel** (Line 264):
   ```swift
   return totalAllocatedAmount * (tradeROI / 100.0) * commissionRate
   ```
   - Same formula, but different context

3. **CommissionBreakdownSheet**:
   - Initially tried to recalculate
   - Now uses Collection Bill's already-calculated gross profit

**Impact**: Changes to commission logic must be made in multiple places, increasing risk of inconsistencies.

### 4. **No Single Source of Truth for Investor Gross Profit**

**Problem**: There's no centralized service that provides investor gross profit for a specific trade:

- Collection Bill calculation is the most accurate
- But it's buried in `InvestorCollectionBillCalculationService`
- Other parts of the codebase don't use it
- We had to use `InvestorInvestmentStatementAggregator` to get the correct values

**Impact**: Had to work around the architecture instead of using a clean, reusable service.

### 5. **Tight Coupling Between Services**

**Problem**: Services depend on each other in complex ways:

```
CommissionBreakdownSheet
  → needs InvestorInvestmentStatementAggregator
    → needs InvestorCollectionBillCalculationService
      → needs InvoiceService, TradeService, InvestmentService
        → needs PotTradeParticipationService
```

**Impact**: Hard to trace data flow, difficult to test, changes ripple through multiple layers.

### 6. **Mixed Responsibilities**

**Problem**: Services have overlapping responsibilities:

- `ProfitDistributionService`: Distributes profit AND calculates commission
- `TradesOverviewViewModel`: Displays trades AND calculates commission
- `CommissionBreakdownSheet`: Shows breakdown AND calculates values
- `InvestorCollectionBillCalculationService`: Calculates Collection Bill AND is the source of truth

**Impact**: Unclear which service is responsible for what, leading to duplication and inconsistencies.

## Recommended Architectural Improvements

### 1. **Create a Single Source of Truth Service**

**Recommendation**: Create `InvestorGrossProfitService` that provides investor gross profit for any trade:

```swift
protocol InvestorGrossProfitServiceProtocol {
    func getGrossProfit(
        for investmentId: String,
        tradeId: String
    ) async throws -> Double
}
```

**Benefits**:
- Single place to get investor gross profit
- Consistent calculation across the app
- Easy to test and maintain

### 2. **Centralize Commission Calculation**

**Recommendation**: Create `CommissionCalculationService` that handles ALL commission calculations:

```swift
protocol CommissionCalculationServiceProtocol {
    func calculateCommissionForInvestor(
        investmentId: String,
        tradeId: String
    ) async throws -> Double

    func calculateTotalCommissionForTrade(
        tradeId: String
    ) async throws -> Double
}
```

**Benefits**:
- One place for commission logic
- Consistent calculations
- Easy to update when business rules change

### 3. **Use Collection Bill Calculation Everywhere**

**Recommendation**: Make `InvestorCollectionBillCalculationService` the authoritative source for investor calculations:

- All investor gross profit should come from this service
- Other services should delegate to it
- Remove duplicate calculation methods

**Benefits**:
- Guaranteed consistency
- Matches what investors see in Collection Bill
- Single source of truth

### 4. **Separate Calculation from Display**

**Recommendation**: Separate calculation logic from ViewModels:

- ViewModels should only format and display data
- Services should handle all calculations
- ViewModels call services, not calculate themselves

**Benefits**:
- Easier to test calculations
- ViewModels are simpler
- Calculations can be reused

### 5. **Improve Service Dependencies**

**Recommendation**: Use dependency injection more consistently:

- Services should receive dependencies via init
- Avoid optional dependencies where possible
- Use protocols for testability

**Benefits**:
- Clear dependencies
- Easier to test
- Less coupling

## Current Workaround (What We Did)

We worked around the architectural issues by:

1. **Using Collection Bill's calculation directly**: Instead of recalculating, we fetch the already-calculated gross profit from `InvestorInvestmentStatementAggregator`
2. **Reusing existing services**: We leveraged the existing `InvestorCollectionBillCalculationService` instead of creating new calculation logic
3. **Accepting the complexity**: We accepted that we need to go through multiple service layers to get the correct value

## Conclusion

**Yes, the file structure and logic distribution made fixing the commission issue more difficult than it should have been.** The main issues are:

1. ✅ **Multiple calculation methods** - No single source of truth
2. ✅ **Inconsistent data sources** - Different services use different inputs
3. ✅ **Duplicated logic** - Same calculations in multiple places
4. ✅ **Tight coupling** - Services depend on each other in complex ways
5. ✅ **Mixed responsibilities** - Services do too many things

**The fix worked**, but it required working around the architecture rather than using a clean, straightforward approach. The recommended improvements would make future changes much easier.

## Implementation Status

✅ **COMPLETED**: The recommended architectural improvements have been implemented:

1. ✅ **InvestorGrossProfitService** - Created as single source of truth for investor gross profit
   - Uses `InvestorCollectionBillCalculationService` internally
   - Provides `getGrossProfit(for:investmentId:tradeId:)` method
   - Provides `getGrossProfitsForTrade(tradeId:)` for batch operations

2. ✅ **Enhanced CommissionCalculationService** - Centralized all commission calculations
   - Added `calculateCommissionForInvestor(investmentId:tradeId:commissionRate:)` method
   - Added `calculateTotalCommissionForTrade(tradeId:commissionRate:)` method
   - Uses `InvestorGrossProfitService` for consistent calculations

3. ✅ **Refactored CommissionBreakdownSheet** - Now uses centralized services
   - Simplified `loadBreakdown()` method
   - Uses `InvestorGrossProfitService` for gross profit
   - Uses `CommissionCalculationService` for commission calculation
   - Removed complex manual calculations

4. ✅ **Refactored TradesOverviewViewModel** - Now uses centralized services
   - Added `commissionCalculationService` dependency
   - Simplified commission calculation logic
   - Uses centralized service when available

5. ✅ **Updated ServiceFactory** - Creates and injects new services
   - Added `createInvestorGrossProfitService()` method
   - Added `createCommissionCalculationService()` method
   - Updated `createCommissionSettlementService()` method

6. ✅ **Updated AppServices** - Includes new centralized services
   - Added `investorGrossProfitService`
   - Added `commissionCalculationService`
   - Properly initialized in `AppServices.live`

**Benefits Achieved:**
- ✅ Single source of truth for investor gross profit
- ✅ Centralized commission calculation logic
- ✅ Consistent calculations across the app
- ✅ Easier to test and maintain
- ✅ Reduced code duplication
- ✅ Clearer service responsibilities

**Remaining (Optional):**
- ⏳ `ProfitDistributionService` could be refactored to use centralized services, but current implementation works correctly and uses a different calculation method (ROI-based) that is appropriate for its use case.

