# Terminology Guide: Profit vs Return

## Overview
This document clarifies the distinction between "Profit" and "Return" terminology used throughout the codebase to prevent confusion for developers.

## Key Distinction

### **Profit** = Actual Monetary Amounts (Currency Values)
- **Type**: `Double` representing currency amounts (e.g., 100.50 EUR)
- **Calculation**: Sell proceeds - Buy costs
- **Examples**:
  - `ProfitCalculationService` - Calculates actual profit/loss amounts
  - `calculatedProfit` - Actual profit amount in currency
  - `profitLoss` - Actual profit/loss amount (can be negative)
  - `grossProfit` - Actual gross profit amount
  - `preTaxProfit` - Actual profit before taxes

**When to use "Profit":**
- When dealing with actual monetary amounts (currency values)
- When calculating sell proceeds minus buy costs
- When displaying currency-formatted values (e.g., "100.50 EUR")

### **Return** = Percentage-Based Metrics (ROI)
- **Type**: `Double` representing percentages (e.g., 15.5%)
- **Calculation**: (Profit / Investment Cost) × 100
- **Examples**:
  - `returnPercentage` - Return percentage for display
  - `averageReturn` - Average return percentage
  - `totalReturn` - Total return percentage
  - `averageReturnLastNTrades` - Average return for last N trades
  - `returnRate` - Filter type for return-based filtering
  - `returnFactor` - Return factor calculation

**When to use "Return":**
- When dealing with percentage-based metrics
- When calculating ROI (Return on Investment)
- When displaying percentage values (e.g., "15.5%")
- When filtering or sorting by return metrics

## Code Examples

### Profit (Monetary Amount)
```swift
// Actual profit amount in currency
let profitAmount: Double = 100.50 // EUR
let calculatedProfit = ProfitCalculationService.calculateTaxableProfit(...)
let profitLoss = sellAmount - buyAmount
```

### Return (Percentage)
```swift
// Return percentage
let returnPercentage: String = "15.5%"
let averageReturn: Double = 15.5 // percentage
let roi = (profitLoss / investmentCost) * 100
```

## Service Naming

- **`ProfitCalculationService`**: ✅ Correct - calculates actual profit amounts
- **`ReturnCalculationService`**: ❌ Would be incorrect - this would imply percentage calculations

## Model Properties

### MockTrader
- `averageReturn: Double` - ✅ Return percentage
- `totalReturn: Double` - ✅ Return percentage
- `averageReturnLastNTrades: Double` - ✅ Return percentage
- `performance: Double` - ✅ Return percentage (used for sorting)

### MockTradePerformance
- `profitLoss: Double` - ✅ Actual monetary amount
- `roi: Double` - ✅ Return percentage (calculated from profitLoss)

### Trade
- `calculatedProfit: Double?` - ✅ Actual monetary amount
- `currentPnL: Double?` - ✅ Actual monetary amount (Profit & Loss)

## Filter Types

- `.returnRate` - ✅ Filter by return percentage
- `.highestReturn` - ✅ Filter by highest return
- No `.profitRate` filter - ✅ Removed to avoid confusion

## Best Practices

1. **Use "Profit"** for:
   - Actual monetary amounts
   - Currency-formatted values
   - Profit/loss calculations

2. **Use "Return"** for:
   - Percentage-based metrics
   - ROI calculations
   - Return-based filtering and sorting

3. **Documentation**:
   - Always clarify in comments whether a value is monetary or percentage
   - Use type hints and examples in documentation

## Migration Notes

- All return-related metrics have been renamed from "profit" to "return"
- Actual profit/loss calculations remain as "profit" (correct financial terminology)
- This distinction helps maintain clarity between monetary amounts and percentage metrics



