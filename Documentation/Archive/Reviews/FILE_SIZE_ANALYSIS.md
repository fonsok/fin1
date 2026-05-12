# File Size Analysis Report
**Date**: Generated on analysis
**Project**: FIN1
**Architecture Standard**: Classes ≤ 500 lines, Functions ≤ 50 lines

## Executive Summary

**Yes, there are files that are too large in the FIN1 project.**

According to the architecture rules (`.cursor/rules/architecture.md`):
- **Classes must be ≤ 500 lines** (rule enforced)
- **Functions must be ≤ 50 lines** (rule enforced)

## Files Exceeding 500 Lines

### Critical Violations (>500 lines)

**✅ UPDATE**: As of current analysis, **no files exceed the 500-line limit**. The previously documented violation has been resolved.

**Previous Status** (for reference):
- `OrderLifecycleCoordinator.swift` was previously 542 lines but has been refactored
- The file is now **298 lines** (well under the limit)
- Profit distribution and commission logic have been extracted to separate services

### Files Near Limit (400-500 lines)

1. **`BuyOrderViewModel.swift`** - **738 lines** ⚠️
   - **Status**: **EXCEEDS LIMIT** - 238 lines over (47.6% over)
   - **Location**: `FIN1/Features/Trader/ViewModels/BuyOrderViewModel.swift`
   - **Note**: ViewModels can be larger due to state management, but this significantly exceeds the limit
   - **Recommendation**: Consider extracting limit order monitoring and investment calculation logic

### Files Near Limit (400-500 lines)

3. **`TradeCalculationTable.swift`** - **493 lines** ⚠️
   - **Location**: `FIN1/Features/Trader/Views/Components/TradeCalculationTable.swift`
   - **Type**: SwiftUI View component
   - **Note**: Views can be larger, but this could be broken into smaller sub-components

   - **Status**: Just under limit, but close
   - **Location**: `FIN1/Features/Investor/Services/InvestmentService.swift`
   - **Note**: Already has some separation (uses `InvestmentPoolLifecycleService`, `InvestmentCreationService`, `InvestmentStatusService`), but still large

4. **`TraderPerformanceSection.swift`** - **486 lines** ⚠️
   - **Location**: `FIN1/Features/Investor/Views/TraderDetail/Components/Sections/TraderPerformanceSection.swift`
   - **Type**: SwiftUI View component
   - **Note**: Could be broken into smaller sub-components

6. **`QRCodeGenerator.swift`** - **436 lines** ✅
   - **Location**: `FIN1/Features/Trader/Utils/QRCodeGenerator.swift`
   - **Type**: Utility class
   - **Status**: Acceptable for utility classes with many features

7. **`MockDataGenerator.swift`** - **431 lines** ✅
   - **Location**: `FIN1/Features/Trader/Services/MockDataGenerator.swift`
   - **Type**: Mock data service
   - **Status**: Acceptable for comprehensive mock data generation

8. **`CompletedInvestmentDetailSheet.swift`** - **417 lines** ✅
   - **Location**: `FIN1/Features/Investor/Views/Components/CompletedInvestmentDetailSheet.swift`
   - **Type**: SwiftUI View
   - **Status**: Acceptable for complex detail views

9. **`Investment.swift`** - **414 lines** ⚠️
   - **Location**: `FIN1/Features/Investor/Models/Investment.swift`
   - **Type**: Model struct
   - **Note**: Large model with many properties and computed properties - consider if all are necessary

10. **`TradeStatementDisplayDataBuilder.swift`** - **409 lines** ✅
    - **Location**: `FIN1/Features/Trader/Services/TradeStatementDisplayDataBuilder.swift`
    - **Type**: Builder pattern
    - **Status**: Acceptable for builder classes

11. **`FIN1App.swift`** - **407 lines** ✅
    - **Location**: `FIN1/FIN1App.swift`
    - **Type**: App composition root
    - **Status**: Acceptable for DI container setup

## Detailed Analysis

### OrderLifecycleCoordinator.swift (298 lines) - ✅ RESOLVED

**Status**: ✅ **REFACTORED** - File has been reduced from 542 lines to 298 lines

**What Was Done:**
- Profit distribution logic extracted to `ProfitDistributionService`
- Commission calculation extracted to `CommissionCalculationService`
- Investment activation extracted to `InvestmentActivationService`
- Coordinator now focuses on order lifecycle orchestration only

**Current State:**
- File is well under the 500-line limit
- Proper separation of concerns achieved
- No further refactoring needed

---

### BuyOrderViewModel.swift (738 lines) - ⚠️ NEW VIOLATION

**Main Issues:**
1. **Exceeds Limit**: 238 lines over the 500-line limit (47.6% over)
2. **Multiple Responsibilities**:
   - Order placement
   - Quantity validation
   - Price monitoring
   - Investment calculation
   - Limit order monitoring

**Refactoring Recommendations:**
1. Extract limit order monitoring to `LimitOrderMonitoringService`
2. Extract investment calculation coordination to separate service
3. Consider splitting into smaller ViewModels if responsibilities can be separated

### InvestmentService.swift (496 lines) - WARNING

**Current State:**
- Already delegates to:
  - `InvestmentRepository`
  - `InvestmentQueryService`
  - `InvestmentCreationService`
  - `InvestmentPoolLifecycleService`
  - `InvestmentStatusService` (injectable via `InvestmentStatusServiceProtocol`)
  - `InvestmentCompletionService`

**Recommendation:**
- Service is well-structured but still large
- Consider if any remaining logic can be extracted
- Current size is acceptable but monitor for growth

### BuyOrderViewModel.swift (738 lines) - ⚠️ CRITICAL

**Current State:**
- Complex ViewModel managing:
  - Order placement
  - Quantity validation
  - Price monitoring
  - Investment calculation
  - Limit order monitoring

**Issue:**
- **Exceeds 500-line limit by 238 lines (47.6% over)**
- Significantly larger than recommended

**Recommendation:**
- **Priority**: Extract limit order monitoring to `LimitOrderMonitoringService`
- Extract investment calculation coordination logic
- Consider splitting responsibilities if possible
- Target: <500 lines

## Recommendations

### Priority 1: Critical (Must Fix)
1. **Refactor `BuyOrderViewModel.swift`** (738 lines)
   - Extract limit order monitoring to `LimitOrderMonitoringService`
   - Extract investment calculation coordination logic
   - Consider splitting responsibilities if possible
   - Target: <500 lines

### Priority 2: High (Should Fix)
2. **Review `InvestmentCreationService.swift`** (510 lines)
   - Review and extract if possible
   - Target: <500 lines

3. **Review `InvestmentService.swift`** (496 lines)
   - Break into smaller sub-components:
     - `SecurityInfoTable`
     - `TransactionDetailsTable`
     - `TaxBreakdownTable`
     - `FinalResultTable`
   - Target: Main file <300 lines, components <150 lines each

### Priority 3: Medium (Consider)
4. **Review `InvestmentService.swift`** (489 lines)
   - Verify all logic is properly delegated
   - Consider if any remaining methods can be extracted
   - Target: <450 lines

5. **Review `TraderPerformanceSection.swift`** (487 lines)
   - Extract sub-components for better maintainability
   - Target: Main file <300 lines

## Best Practices Applied

✅ **Good Examples:**
- `InvestmentService` already uses proper separation with multiple service dependencies
- Most files are under 500 lines
- Project has good separation of concerns overall

❌ **Areas for Improvement:**
- `OrderLifecycleCoordinator` violates Single Responsibility Principle
- Some ViewModels approaching limits need monitoring
- Some View components could be more modular

## Conclusion

**Answer: Yes, there are files that exceed the 500-line limit:**
- `BuyOrderViewModel.swift` at 738 lines (47.6% over limit) - **NEW VIOLATION**
- `InvestmentCreationService.swift` at 510 lines (2% over limit) - **NEW VIOLATION**

**Additionally, several files are approaching the limit and should be monitored:**
- `InvestmentService.swift` (496 lines)
- `TraderPerformanceSection.swift` (486 lines)
- `InvestmentActivationService.swift` (479 lines)

**Status Update:**
- ✅ `OrderLifecycleCoordinator.swift` has been refactored (298 lines, down from 542)
- ⚠️ New violations identified that need attention

**Recommended Action:**
1. **Immediate**: Refactor `BuyOrderViewModel.swift` to extract limit order monitoring and investment calculation logic
2. **Short-term**: Review `InvestmentCreationService.swift` and extract if possible
3. **Ongoing**: Monitor file sizes during development to prevent future violations


