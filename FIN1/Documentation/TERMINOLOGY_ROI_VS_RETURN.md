# Terminology: ROI vs Return - Standardization Guide

## Problem Statement

The codebase uses two different terms for the same concept:
- **Trader**: "ROI" (Return on Investment)
- **Investor**: "return" or "return percentage"

Both refer to the same calculation: `(profit / invested amount) * 100`

## Current Usage

### Trader Side
- **Property**: `Trade.roi: Double?`
- **Display**: "ROI" or "Return %"
- **Calculation**: `ProfitCalculationService.calculateReturnPercentage()`

### Investor Side
- **Property**: `Investment.performance: Double`
- **Display**: "Return" or "Return %"
- **Calculation**: `ProfitCalculationService.calculateReturnPercentage()`

### Shared Function
- **Function**: `ProfitCalculationService.calculateReturnPercentage(grossProfit:investedAmount:)`
- **Purpose**: Single source of truth for the calculation

## Terminology Standardization

### Recommended Standard: **"Return" or "Return Percentage"**

**Rationale**:
1. ✅ More general term (doesn't imply "investment" specifically)
2. ✅ Matches financial industry terminology
3. ✅ Already used in shared function name
4. ✅ Consistent with `TERMINOLOGY_PROFIT_VS_RETURN.md` guide
5. ✅ "ROI" is technically correct but more specific

### Current Property Names (Keep for Backward Compatibility)

**Trade Model**:
- `roi: Double?` - ✅ Keep (breaking change to rename)
- **Comment**: "Return percentage (ROI)"

**Investment Model**:
- `performance: Double` - ✅ Keep (breaking change to rename)
- **Comment**: "Return percentage"

### Documentation Standard

**In code comments and documentation**:
- ✅ Use "return percentage" or "return" as the primary term
- ✅ "ROI" can be used as a synonym in parentheses: "return percentage (ROI)"
- ✅ Be consistent: don't mix "ROI" and "return" in the same context

**Examples**:
```swift
// ✅ GOOD: Primary term is "return"
/// Calculates return percentage (ROI) from gross profit and invested amount

// ✅ GOOD: Consistent terminology
/// Return percentage for this trade
var roi: Double?

// ❌ AVOID: Mixing terms
/// Calculates ROI and return percentage  // Confusing!
```

## Migration Strategy

### Phase 1: Documentation (Current)
- ✅ Document that ROI and return are the same thing
- ✅ Update comments to use "return percentage" as primary term
- ✅ Add "ROI" as synonym in parentheses where helpful

### Phase 2: Future (If Needed)
- Consider renaming `Trade.roi` to `Trade.returnPercentage` in a major version
- Consider renaming `Investment.performance` to `Investment.returnPercentage` in a major version
- **Note**: These would be breaking changes, so only do in major version updates

## Code Examples

### Current (Acceptable)
```swift
// Trader
var roi: Double? {
    // Return percentage calculation
    return ProfitCalculationService.calculateReturnPercentage(...)
}

// Investor
let returnPercentage = ProfitCalculationService.calculateReturnPercentage(...)
```

### Future (If Renamed)
```swift
// Trader
var returnPercentage: Double? {
    // Return percentage calculation
    return ProfitCalculationService.calculateReturnPercentage(...)
}

// Investor
var returnPercentage: Double {
    performance  // Return percentage
}
```

## Summary

- **Same Concept**: ROI and return percentage are the same thing
- **Current State**: Different property names (`roi` vs `performance`) but same calculation
- **Standard Term**: Use "return percentage" in documentation and comments
- **Property Names**: Keep current names for backward compatibility
- **Shared Function**: `calculateReturnPercentage()` is the single source of truth

## Related Documentation

- `TERMINOLOGY_PROFIT_VS_RETURN.md` - Profit vs Return distinction
- `DRY_VIOLATION_RETURN_PERCENTAGE_CALCULATION.md` - Shared calculation function

















