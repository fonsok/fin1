# Calculation Scheme Protection

## Overview

This document describes the comprehensive protection system implemented to ensure the calculation scheme is always used consistently and is not disrupted by old data or incorrect methods.

## 🛡️ Protection Layers

### 1. Calculation Validation Service

**Purpose**: Validates that all calculations follow the standardized scheme and are consistent.

**Key Features**:
- Validates profit calculation consistency
- Validates tax calculation consistency
- Validates that tax items are excluded from profit calculations
- Validates that correct calculation methods are used
- Validates invoice data integrity

**Usage**:
```swift
let result = CalculationValidationService.validateCalculationConsistency(
    buyInvoice: buyInvoice,
    sellInvoices: sellInvoices,
    expectedProfit: expectedProfit,
    expectedTaxes: expectedTaxes
)

if !result.isValid {
    // Handle validation errors
    for error in result.errors {
        print("Validation error: \(error)")
    }
}
```

### 2. Calculation Guard Service

**Purpose**: Ensures only the correct calculation methods are used and prevents old/incorrect calculations from being executed.

**Key Features**:
- Guards profit calculations to use `ProfitCalculationService.calculateTaxableProfit`
- Guards tax calculations to use `InvoiceTaxCalculator.calculateTotalTax`
- Guards fee calculations to use `FeeCalculationService.createFeeBreakdown`
- Guards invoice filtering to exclude tax items from profit calculations
- Provides comprehensive calculation flow validation

**Usage**:
```swift
// Guard profit calculation
let profit = CalculationGuardService.shared.guardProfitCalculation(
    buyInvoice: buyInvoice,
    sellInvoices: sellInvoices
)

// Guard complete calculation flow
let result = CalculationGuardService.shared.guardCompleteCalculation(
    buyInvoice: buyInvoice,
    sellInvoices: sellInvoices
)
```

### 3. Deprecated Method Warnings

**Purpose**: Prevents old calculation methods from being used by marking them as deprecated.

**Implementation**:
```swift
@available(*, deprecated, message: "Use InvoiceTaxCalculator.calculateTotalTax(for:) instead")
func calculateTotalTax(buyInvoice: Invoice?, sellInvoices: [Invoice]) -> Double {
    // Redirect to correct method
    let profit = ProfitCalculationService.calculateTaxableProfit(buyInvoice: buyInvoice, sellInvoices: sellInvoices)
    return InvoiceTaxCalculator.calculateTotalTax(for: profit)
}
```

## 🔒 Standardized Calculation Flow

### Step 1: Profit Calculation (Ergebnis vor Steuern)
```swift
// ✅ CORRECT - Always use this method
let profit = ProfitCalculationService.calculateTaxableProfit(
    buyInvoice: buyInvoice,
    sellInvoices: sellInvoices
)

// ❌ WRONG - Never use old methods
let profit = calculateNetCashFlow(buyInvoice: buyInvoice, sellInvoices: sellInvoices)
```

### Step 2: Tax Calculations
```swift
// ✅ CORRECT - Always use these methods
let capitalGainsTax = InvoiceTaxCalculator.calculateCapitalGainsTax(for: profit)
let solidaritySurcharge = InvoiceTaxCalculator.calculateSolidaritySurcharge(for: capitalGainsTax)
let churchTax = InvoiceTaxCalculator.calculateChurchTax(for: capitalGainsTax)
let totalTax = InvoiceTaxCalculator.calculateTotalTax(for: profit)

// ❌ WRONG - Never use old methods
let totalTax = calculateTotalTax(buyInvoice: buyInvoice, sellInvoices: sellInvoices)
```

### Step 3: Fee Calculations
```swift
// ✅ CORRECT - Always use this method
let fees = FeeCalculationService.createFeeBreakdown(for: orderAmount)

// ❌ WRONG - Never use old methods
let fees = calculateFees(from: invoice)
```

### Step 4: Invoice Filtering
```swift
// ✅ CORRECT - Always use guarded filtering
let items = CalculationGuardService.shared.guardInvoiceFiltering(
    invoice: invoice,
    calculationType: .profitCalculation
)

// ❌ WRONG - Never manually filter without guards
let items = invoice.items.filter { $0.itemType != .tax }
```

## 🧪 Testing

### Unit Tests
All calculation methods are covered by comprehensive unit tests in `CalculationValidationTests.swift`:

- Test calculation consistency with valid data
- Test detection of inconsistent calculations
- Test proper exclusion of tax items
- Test validation of calculation methods
- Test detection of deprecated methods
- Test invoice data validation
- Test complete calculation flow validation

### Running Tests
```bash
# Run all calculation validation tests
xcodebuild test -scheme FIN1 -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:FIN1Tests/CalculationValidationTests
```

## 🚨 Error Handling

### Validation Errors
- `inconsistentTaxCalculation`: Tax calculation doesn't match expected value
- `inconsistentProfitCalculation`: Profit calculation doesn't match expected value
- `oldCalculationMethodUsed`: Deprecated calculation method was used
- `taxItemsIncludedInProfitCalculation`: Tax items were included in profit calculation
- `missingRequiredCalculationStep`: Required calculation step is missing

### Common Calculation Issues Fixed

#### Issue: Calculation Breakdown Discrepancy
**Problem**: The "Berechnung Ergebnis vor Steuern" section showed incorrect results where the displayed breakdown didn't match the final result.

**Example**:
- ∑ Verkauf: + 8.348,10 €
- ∑ Kauf: - 4.266,94 €
- **Expected**: 8.348,10 - 4.266,94 = 4.081,16 €
- **Actual (wrong)**: 12.615,04 €

**Solution**: Fixed `buildCalculationBreakdown` method to ensure the displayed calculation matches the actual breakdown by:
1. Calculating individual sell and buy amounts
2. Computing result as `totalSellAmount - abs(buyAmount)`
3. Validating against the guarded calculation
4. Logging discrepancies for debugging

### Validation Warnings
- `deprecatedMethodUsed`: Deprecated method was used (non-fatal)
- `calculationDeviation`: Calculation deviates from expected value within tolerance

## 🔧 Configuration

### Validation Modes
```swift
// Strict mode - Fail on any inconsistency
CalculationGuardService.shared.setValidationMode(.strict)

// Warning mode - Log warnings but allow execution
CalculationGuardService.shared.setValidationMode(.warning)

// Disabled mode - No validation
CalculationGuardService.shared.setValidationMode(.disabled)
```

### Enable/Disable Validation
```swift
// Enable validation (default)
CalculationGuardService.shared.setValidationEnabled(true)

// Disable validation (for performance in production)
CalculationGuardService.shared.setValidationEnabled(false)
```

## 📊 Monitoring

### Logging
All validation errors and warnings are logged with clear messages:

```
🚨 CALCULATION VALIDATION ERROR: Profit calculation inconsistency detected
   - inconsistentProfitCalculation(expected: 1000.0, actual: 1200.0)

⚠️ CALCULATION VALIDATION WARNING: Fee calculation deviation detected
   - calculationDeviation(expected: 50.0, actual: 52.0, tolerance: 0.01)
```

### Metrics
Track validation results to monitor calculation consistency:
- Number of validation errors per calculation
- Types of validation errors
- Calculation method usage patterns
- Performance impact of validation

## 🎯 Best Practices

### Do's ✅
- Always use `CalculationGuardService` for calculations
- Use centralized calculation services (`ProfitCalculationService`, `InvoiceTaxCalculator`, `FeeCalculationService`)
- Run validation in development and testing environments
- Monitor validation logs for inconsistencies
- Write unit tests for all calculation scenarios

### Don'ts ❌
- Never bypass the guard services
- Never use deprecated calculation methods
- Never manually filter invoice items without guards
- Never ignore validation errors
- Never disable validation in development

## 🔄 Migration Guide

### From Old to New Calculation Methods

1. **Replace direct invoice filtering**:
   ```swift
   // Old
   let items = invoice.items.filter { $0.itemType != .tax }

   // New
   let items = CalculationGuardService.shared.guardInvoiceFiltering(
       invoice: invoice,
       calculationType: .profitCalculation
   )
   ```

2. **Replace manual profit calculations**:
   ```swift
   // Old
   let profit = calculateNetCashFlow(buyInvoice: buyInvoice, sellInvoices: sellInvoices)

   // New
   let profit = CalculationGuardService.shared.guardProfitCalculation(
       buyInvoice: buyInvoice,
       sellInvoices: sellInvoices
   )
   ```

3. **Replace manual tax calculations**:
   ```swift
   // Old
   let tax = calculateTotalTax(buyInvoice: buyInvoice, sellInvoices: sellInvoices)

   // New
   let tax = CalculationGuardService.shared.guardTaxCalculation(profit: profit)
   ```

## 🚀 Future Enhancements

1. **Real-time Validation**: Add real-time validation in the UI
2. **Performance Monitoring**: Add performance metrics for calculation methods
3. **Automated Testing**: Add automated tests that run on every build
4. **Documentation Generation**: Auto-generate calculation documentation
5. **Visual Validation**: Add visual indicators for calculation consistency

## 📞 Support

For questions or issues with the calculation protection system:
1. Check the validation logs for specific error messages
2. Review the unit tests for expected behavior
3. Consult this documentation for proper usage patterns
4. Contact the development team for complex issues
