---
alwaysApply: true
---

# DRY (Don't Repeat Yourself) & Constants

## Core Principles

- **MANDATORY**: All magic numbers, percentages, rates, and repeated string values must be defined as constants.
- **FORBIDDEN**: Hardcoded numeric values (percentages, rates, fees, limits) in multiple places.
- **REQUIRED**: Use `CalculationConstants` in `FIN1/Shared/Models/CalculationConstants.swift` for all financial calculations.
- **REQUIRED**: Define both calculation values (Double) and display strings (String) for percentages/rates.
- **FORBIDDEN**: Duplicating the same percentage/rate value in multiple files (e.g., `0.015`, `1.5%`).

## When Adding New Fees, Rates, or Percentages

1. Add to `CalculationConstants.FeeRates` (or appropriate struct)
2. Define both the numeric value and display string
3. Reference the constant everywhere it's used

## Example Pattern

```swift
// ✅ CORRECT - In CalculationConstants.swift
struct FeeRates {
    static let platformFeeRate: Double = 0.015
    static let platformFeePercentage: String = "1.5%"
}

// ✅ CORRECT - Usage
let fee = amount * CalculationConstants.FeeRates.platformFeeRate
Text("Fee: \(CalculationConstants.FeeRates.platformFeePercentage)")

// ❌ FORBIDDEN - Magic numbers
let fee = amount * 0.015
Text("Fee: 1.5%")
```

## Detection Guidelines

- **Before Committing**: Search codebase for duplicate numeric/string values
- **Code Review**: Check if the same value appears in multiple files
- **If Found**: Extract to `CalculationConstants` and reference the constant everywhere

## Constants Location Guide

- **Financial/calculation constants** → `CalculationConstants.swift`
- **UI constants** → `ResponsiveDesign.swift`
- **Feature-specific constants** → Feature's Models folder
- **Document/display placeholders** (z. B. Handelsplatz bis Produktion) → `TradeStatementPlaceholders` in `TradeStatementDisplayData.swift`
- **Emittent-Mapping (WKN → Anzeigename)** → Single source: `String.emittentName(forWKN:)` in `FIN1/Shared/Extensions/String+Emittent.swift`; nicht duplizieren

## Automated Detection

When adding fees, rates, or percentages:
- Check if the same numeric value (e.g., `0.015`, `0.02`) appears in multiple files
- Check if the same string value (e.g., `"1.5%"`, `"2%"`) appears in multiple files
- If found, extract to `CalculationConstants` and reference the constant everywhere
- Manual review: Search codebase for duplicate numeric/string values before committing


