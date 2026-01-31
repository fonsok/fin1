# MVVM Architecture Validation Guide

## Overview

This document describes the comprehensive MVVM architecture validation system implemented in FIN1. The system uses multiple layers of detection to ensure all Views follow proper MVVM patterns.

## Validation Layers

### 1. SwiftLint Rules (Real-time in IDE)

SwiftLint provides immediate feedback in Xcode with custom rules:

#### Data Formatting Detection
- **Rule**: `no_data_formatting_in_view`
- **Detects**: `.formatted()`, `.formattedAs()`, `.formattedAsLocalized()` in Views
- **Severity**: Error
- **Excludes**: ViewModels, Models, Extensions

#### Date Formatting Detection
- **Rule**: `no_date_formatting_in_view`
- **Detects**: `.formatted(date:` in Views
- **Severity**: Error
- **Excludes**: ViewModels, Models, Extensions

#### Direct Model Access Detection
- **Rule**: `no_direct_model_property_access_in_view`
- **Detects**: Direct access to model properties (e.g., `investment.amount`)
- **Severity**: Warning
- **Excludes**: ViewModels, Models, Wrappers

#### Model Formatting Without ViewModel
- **Rule**: `no_model_formatting_without_viewmodel`
- **Detects**: Model property formatting without ViewModel (e.g., `investment.amount.formattedAsLocalizedCurrency()`)
- **Severity**: Error
- **Excludes**: ViewModels, Models, Extensions

### 2. MVVM Validation Script (Pre-commit)

The `validate-mvvm-architecture.sh` script performs deeper analysis:

#### Checks Performed

1. **Missing ViewModel Detection**
   - Scans Views for model properties
   - Checks if ViewModel exists
   - Verifies ViewModel is referenced in View

2. **Data Formatting in Views**
   - Detects formatting methods in View files
   - Excludes ViewModels, Models, Extensions

3. **Date Formatting in Views**
   - Detects date formatting in View files
   - Excludes ViewModels, Models, Extensions

4. **Business Logic in Views**
   - Detects `filter()`, `map()`, `reduce()`, `sorted()`, `Dictionary(grouping:)`
   - Ensures data processing is in ViewModels

5. **ViewModel Instantiation Pattern**
   - Verifies ViewModels are created in `init()`, not property declaration

6. **Direct Service Access**
   - Detects `AppServices.live` usage
   - Ensures dependency injection via `@Environment(\.appServices)`

#### Usage

```bash
# Run manually
./scripts/validate-mvvm-architecture.sh

# Automatically runs in pre-commit hook
git commit -m "Your message"
```

### 3. Pre-commit Hook Integration

The validation script is automatically run before each commit:

```bash
# Pre-commit hook runs:
# 1. ResponsiveDesign compliance check
# 2. Main view spacing validation
# 3. SwiftLint
# 4. SwiftFormat
# 5. MVVM architecture validation ← NEW
```

## Detection Capabilities

### ✅ Fully Automated Detection

| Violation | SwiftLint | Validation Script | Protection Level |
|-----------|-----------|-------------------|------------------|
| Data formatting in View | ✅ Error | ✅ Error | **High** |
| Date formatting in View | ✅ Error | ✅ Error | **High** |
| Business logic in View | ✅ Error | ✅ Error | **High** |
| ViewModel init pattern | ✅ Error | ✅ Error | **High** |
| Direct service access | ✅ Error | ✅ Error | **High** |
| Model formatting w/o ViewModel | ✅ Error | ✅ Error | **High** |

### ⚠️ Partial Detection (Warning Level)

| Violation | SwiftLint | Validation Script | Protection Level |
|-----------|-----------|-------------------|------------------|
| Missing ViewModel | ⚠️ Warning | ⚠️ Warning | **Medium** |
| Direct model access | ⚠️ Warning | ⚠️ Warning | **Medium** |

**Why Partial?**
- Cannot distinguish legitimate cases (View with model AND ViewModel)
- May flag false positives for wrapper views
- Requires code review for context

## Examples

### ❌ Violation Detected

```swift
struct InvestmentDetailView: View {
    let investment: Investment  // Model property

    var body: some View {
        Text(investment.amount.formattedAsLocalizedCurrency())  // ❌ ERROR
        Text(investment.createdAt.formatted(date: .abbreviated))  // ❌ ERROR
    }
}
```

**Detection:**
- SwiftLint: 2 errors (formatting in View)
- Validation Script: Missing ViewModel warning + formatting errors

### ✅ Correct Pattern

```swift
struct InvestmentDetailView: View {
    @StateObject private var viewModel: InvestmentDetailViewModel  // ✅ ViewModel

    init(investment: Investment) {
        self._viewModel = StateObject(wrappedValue: InvestmentDetailViewModel(investment: investment))
    }

    var body: some View {
        Text(viewModel.formattedAmount)  // ✅ ViewModel property
        Text(viewModel.formattedCreatedDate)  // ✅ ViewModel property
    }
}
```

**Detection:**
- SwiftLint: No violations
- Validation Script: No violations

## Bypassing Validation

### Emergency Commits

```bash
# Skip all pre-commit hooks (use sparingly!)
git commit --no-verify -m "Emergency fix"
```

### Temporary Exclusions

For legitimate cases, add exclusions to `.swiftlint.yml`:

```yaml
no_direct_model_property_access_in_view:
  excluded:
    - "**/SpecificLegitimateView.swift"
```

## Best Practices

1. **Always create ViewModels** for Views that display model data
2. **Move all formatting** to ViewModel properties
3. **Use ViewModel init pattern** with `@StateObject` in `init()`
4. **Run validation locally** before committing:
   ```bash
   ./scripts/validate-mvvm-architecture.sh
   ```
5. **Fix violations immediately** - don't accumulate technical debt

## Troubleshooting

### False Positives

If a rule flags a legitimate case:
1. Verify it's actually legitimate (not a violation)
2. Add exclusion to `.swiftlint.yml` if needed
3. Document why in code comments

### Script Not Running

```bash
# Make script executable
chmod +x scripts/validate-mvvm-architecture.sh

# Test manually
./scripts/validate-mvvm-architecture.sh
```

### Integration Issues

```bash
# Reinstall git hooks
./scripts/setup-git-hooks.sh
```

## Summary

The multi-layered validation system provides:
- ✅ **Real-time feedback** via SwiftLint in IDE
- ✅ **Deep analysis** via validation script
- ✅ **Pre-commit enforcement** via git hooks
- ✅ **Comprehensive coverage** of MVVM violations

This ensures MVVM architecture compliance is maintained automatically, preventing the violations we fixed in `InvestmentDetailView` from happening again.



