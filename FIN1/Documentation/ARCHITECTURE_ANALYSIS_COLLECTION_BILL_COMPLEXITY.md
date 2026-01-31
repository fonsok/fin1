# Architecture Analysis: Why Collection Bill Calculation Was Difficult

## Executive Summary

The collection bill calculation fix was challenging due to **architectural complexity** rather than just logic complexity. The main issues were:

1. **Unclear data source hierarchy** - Multiple sources of truth without clear precedence
2. **Scattered calculation logic** - Spread across 4+ files with mixed responsibilities
3. **Historical technical debt** - Previous "fixes" that used wrong data sources
4. **Complex data relationships** - Deep chain of dependencies (Investment → Participation → Trade → Invoice)
5. **Mixed concerns** - Business logic intertwined with display/presentation logic

---

## Problem Analysis

### 1. Unclear Data Source Hierarchy

**The Problem**:
- Multiple data sources could be used for the same calculation
- No clear documentation of which source is authoritative
- Previous code comments suggested invoice was "source of truth" (but it wasn't)

**Evidence**:
```swift
// ❌ Previous code (INCORRECT):
// ✅ FIX: Use invoice securities value (source of truth) instead of allocatedAmount
let buyTotal = (buyInvoice?.securitiesTotal ?? 0.0) * ownershipPercentage
```

**Why This Was Wrong**:
- Invoice quantities were incorrect (from earlier bug)
- Investment capital (`Investment.amount`) is the actual source of truth
- But this wasn't documented or enforced

**Impact**:
- Developers couldn't easily determine which data to trust
- Led to using wrong data sources
- Required deep investigation to understand the correct flow

### 2. Scattered Calculation Logic

**Files Involved**:
1. `InvestorInvestmentStatementAggregator.swift` - Aggregation logic
2. `InvestorInvestmentStatementViewModel.swift` - ViewModel with calculation
3. `InvestorInvestmentStatementItem.build()` - Item-level calculation
4. `InvestmentCompletionService.swift` - Completion calculations
5. `ProfitCalculationService.swift` - Profit calculations

**The Problem**:
- Calculation steps are spread across multiple files
- No single place to see the complete calculation flow
- Changes require understanding multiple files
- Hard to trace data flow

**Example Flow**:
```
Aggregator (gets investment capital)
    ↓
ViewModel (calculates trade capital share)
    ↓
Item.build() (calculates buy/sell amounts)
    ↓
ProfitCalculationService (calculates profit)
```

**Impact**:
- Difficult to understand complete flow
- Easy to miss a step when making changes
- Hard to debug issues

### 3. Historical Technical Debt

**The Problem**:
- Previous "fixes" added comments claiming invoice was "source of truth"
- These fixes were incorrect but looked authoritative
- Created confusion about which approach was correct

**Evidence**:
```swift
// ✅ FIX: Use invoice securities value (source of truth) instead of allocatedAmount
// allocatedAmount is from trade creation and may not match actual invoice values
// The invoice contains the actual securities value that was purchased
```

**Reality**:
- Invoice had wrong quantities (from order placement bug)
- Investment capital was the correct source
- But previous fix suggested otherwise

**Impact**:
- Misleading comments led to wrong assumptions
- Required investigation to discover the real issue
- Had to override previous "fixes"

### 4. Complex Data Relationships

**The Chain**:
```
Investment (capital amount)
    ↓
PotTradeParticipation (ownership percentage, allocated amount)
    ↓
Trade (entry price, total quantity)
    ↓
Invoice (quantities, prices, fees)
```

**The Problem**:
- Deep dependency chain
- Each link can have issues
- Hard to trace where data comes from
- Multiple ways to calculate the same thing

**Example Confusion**:
- Buy amount could come from:
  1. `Investment.amount` (capital) ✅ CORRECT
  2. `buyInvoice.securitiesTotal * ownershipPercentage` ❌ WRONG (if invoice qty wrong)
  3. `participation.allocatedAmount` ❌ WRONG (securities value, not capital)
  4. `trade.totalQuantity * ownershipPercentage * buyPrice` ❌ WRONG (if trade qty wrong)

**Impact**:
- Multiple calculation paths
- Unclear which is correct
- Easy to use wrong path

### 5. Mixed Concerns

**The Problem**:
- Business logic (what actually happened) mixed with display logic (what to show)
- Same calculation used for both purposes
- Display calculations affected by business logic issues

**Example**:
```swift
// This is both business logic AND display logic
let buyTotal = (buyInvoice?.securitiesTotal ?? 0.0) * ownershipPercentage
```

**Impact**:
- Can't separate "what happened" from "what to display"
- Display bugs affect business logic
- Hard to test independently

---

## Root Causes

### 1. Lack of Single Source of Truth

**Issue**: No clear definition of which data source is authoritative for each value

**Solution Needed**:
- Document data source hierarchy
- Enforce single source of truth per value
- Add validation to ensure consistency

### 2. No Calculation Service

**Issue**: Calculation logic embedded in ViewModels and aggregators

**Solution Needed**:
- Extract to dedicated `InvestorCollectionBillCalculationService`
- Single place for all calculation logic
- Easier to test and maintain

### 3. Inconsistent Data Flow

**Issue**: Data flows through multiple services without clear contract

**Solution Needed**:
- Define clear data contracts
- Use DTOs (Data Transfer Objects) for calculations
- Document expected data format

### 4. Missing Validation

**Issue**: No validation that data sources are consistent

**Solution Needed**:
- Add validation layer
- Check that invoice quantities match trade quantities
- Warn when data sources disagree

---

## Architectural Improvements

### 1. Create Dedicated Calculation Service

**Proposed Structure**:
```swift
// FIN1/Features/Investor/Services/InvestorCollectionBillCalculationService.swift

protocol InvestorCollectionBillCalculationServiceProtocol {
    func calculateCollectionBill(
        investment: Investment,
        participations: [PotTradeParticipation],
        trades: [Trade],
        invoices: [Invoice]
    ) -> InvestorCollectionBillResult
}

struct InvestorCollectionBillResult {
    let buyAmount: Double
    let buyQuantity: Double
    let buyPrice: Double
    let buyFees: Double
    let sellAmount: Double
    let sellQuantity: Double
    let sellPrice: Double
    let sellFees: Double
    let grossProfit: Double
}
```

**Benefits**:
- Single place for all calculation logic
- Easier to test
- Clear separation of concerns
- Can be reused by multiple views

### 2. Define Data Source Hierarchy

**Proposed Hierarchy**:
```
1. Investment.amount (CAPITAL) - Source of truth for buy amount
2. Trade.entryPrice - Source of truth for buy price
3. Invoice (fees) - Source of truth for fees
4. Invoice (sell prices) - Source of truth for sell prices
5. Trade.totalQuantity - Reference for sell percentage calculation
```

**Documentation**:
- Create data source documentation
- Add comments explaining why each source is used
- Add validation to ensure sources are consistent

### 3. Use DTOs for Calculations

**Proposed Structure**:
```swift
struct InvestorCollectionBillInput {
    let investmentCapital: Double
    let buyPrice: Double
    let sellInvoices: [Invoice]
    let buyInvoice: Invoice?
    let ownershipPercentage: Double
    let tradeTotalQuantity: Double
}

struct InvestorCollectionBillOutput {
    let buyAmount: Double
    let buyQuantity: Double
    let buyFees: Double
    let sellAmount: Double
    let sellQuantity: Double
    let sellFees: Double
    let grossProfit: Double
}
```

**Benefits**:
- Clear input/output contracts
- Easier to test
- Can validate inputs
- Self-documenting

### 4. Add Validation Layer

**Proposed Validation**:
```swift
func validateCollectionBillInput(_ input: InvestorCollectionBillInput) -> ValidationResult {
    // Check that investment capital is positive
    guard input.investmentCapital > 0 else {
        return .error("Investment capital must be positive")
    }

    // Check that buy price is positive
    guard input.buyPrice > 0 else {
        return .error("Buy price must be positive")
    }

    // Warn if invoice quantities seem inconsistent
    if let buyInvoice = input.buyInvoice {
        let invoiceQty = buyInvoice.securitiesItems.reduce(0) { $0 + $1.quantity }
        let calculatedQty = input.investmentCapital / input.buyPrice
        let difference = abs(invoiceQty - calculatedQty)
        if difference > 0.01 {
            return .warning("Invoice quantity (\(invoiceQty)) differs from calculated quantity (\(calculatedQty))")
        }
    }

    return .valid
}
```

**Benefits**:
- Catch data inconsistencies early
- Provide clear error messages
- Help debug issues

### 5. Separate Business Logic from Display Logic

**Proposed Structure**:
```swift
// Business Logic Layer
struct InvestorCollectionBillCalculation {
    // Pure calculation, no display formatting
    func calculate(input: InvestorCollectionBillInput) -> InvestorCollectionBillOutput
}

// Display Layer
struct InvestorCollectionBillFormatter {
    // Formatting for display only
    func format(calculation: InvestorCollectionBillOutput) -> InvestorCollectionBillDisplay
}
```

**Benefits**:
- Business logic can be tested independently
- Display logic can change without affecting calculations
- Clear separation of concerns

---

## Specific Issues Found

### Issue 1: Invoice as "Source of Truth" Comment

**Location**: `InvestorInvestmentStatementViewModel.swift:108`

**Problem**:
```swift
// ✅ FIX: Use invoice securities value (source of truth) instead of allocatedAmount
// allocatedAmount is from trade creation and may not match actual invoice values
// The invoice contains the actual securities value that was purchased
let buyTotal = (buyInvoice?.securitiesTotal ?? 0.0) * ownershipPercentage
```

**Why Wrong**:
- Invoice quantities were incorrect (from order placement bug)
- Investment capital is the actual source of truth
- Comment was misleading

**Fix Applied**:
- Changed to use `Investment.amount` (capital)
- Updated comment to reflect correct source
- Added logging to show which source is used

### Issue 2: Scattered Capital Share Calculation

**Location**:
- `InvestorInvestmentStatementAggregator.swift` (for aggregator)
- `InvestorInvestmentStatementViewModel.swift` (for ViewModel)

**Problem**:
- Same logic duplicated in two places
- Easy to get out of sync
- Hard to maintain

**Fix Applied**:
- Added calculation in both places (necessary for now)
- Added extensive logging
- Documented the logic

**Future Improvement**:
- Extract to shared calculation service
- Single source of truth for calculation

### Issue 3: Sell Amount Calculation

**Location**: `InvestorInvestmentStatementViewModel.swift:178`

**Problem**:
```swift
// Wrong approach:
let investorSellValue = totalSellValueFromInvoices * ownershipPercentage
```

**Why Wrong**:
- Doesn't match displayed quantity
- Example: Shows 1,500 Stk but calculates from scaled value
- Should be: `investorSellQty * sellAvgPrice`

**Fix Applied**:
- Changed to quantity-based calculation
- Ensures consistency with displayed values

---

## Complexity Metrics

### Files Involved
- **Calculation Logic**: 5 files
- **Data Models**: 4 models (Investment, Trade, Invoice, Participation)
- **Services**: 4 services (Investment, Trade, Invoice, Participation)

### Calculation Steps
- **Buy Leg**: 4 steps
- **Sell Leg**: 5 steps
- **Fee Allocation**: 2 steps (buy + sell)
- **Profit**: 2 calculations (gross + ROI)

### Data Dependencies
- **Investment** → Capital amount
- **Participation** → Ownership percentage
- **Trade** → Entry price, total quantity
- **Invoice** → Fees, sell prices, quantities (for reference)

### Lines of Code
- **Calculation Logic**: ~200 lines
- **Spread across**: 5 files
- **Average per file**: ~40 lines

---

## Recommendations

### Short-Term (Immediate)

1. **Document Data Sources** ✅ **COMPLETED**
   - ✅ Created `Documentation/DATA_SOURCE_HIERARCHY.md` with complete data source documentation
   - ✅ Added comments explaining why each source is used
   - ✅ Updated service documentation with references to data source hierarchy

2. **Add Validation**
   - Validate that investment capital matches expected values
   - Check that invoice quantities are reasonable
   - Warn when data sources disagree

3. **Improve Logging**
   - Add comprehensive logging (already done)
   - Log which data sources are used
   - Log calculation steps

### Medium-Term (Next Sprint)

1. **Extract Calculation Service** ✅ **COMPLETED**
   - ✅ Created `InvestorCollectionBillCalculationService` with protocol
   - ✅ Moved all calculation logic to single service
   - ⏳ Add unit tests (next step)

2. **Create DTOs** ✅ **COMPLETED**
   - ✅ Defined `InvestorCollectionBillInput` and `InvestorCollectionBillOutput` DTOs
   - ✅ Clear contracts for calculations
   - ✅ Easier to test

3. **Add Unit Tests** ⏳ **NEXT STEP**
   - Test calculation service independently
   - Test with various scenarios
   - Test edge cases

### Long-Term (Future)

1. **Refactor Data Model**
   - Consider storing calculated values
   - Reduce dependency chain
   - Simplify relationships

2. **Add Caching**
   - Cache calculation results
   - Invalidate on data changes
   - Improve performance

3. **Create Calculation DSL**
   - Domain-specific language for calculations
   - More readable
   - Easier to maintain

---

## Conclusion

The collection bill calculation was difficult to fix due to **architectural complexity**:

1. **Unclear data source hierarchy** - Multiple sources without clear precedence
2. **Scattered logic** - Calculation spread across multiple files
3. **Historical debt** - Previous "fixes" that were incorrect
4. **Complex relationships** - Deep dependency chain
5. **Mixed concerns** - Business logic mixed with display logic

**The fix required**:
- Deep investigation of data flow
- Understanding multiple files
- Identifying correct data sources
- Overriding previous "fixes"

**To prevent future issues**:
- Create dedicated calculation service
- Document data source hierarchy
- Add validation
- Separate business logic from display logic
- Add comprehensive tests

The current fix works, but the architecture could be improved to make future changes easier and less error-prone.

