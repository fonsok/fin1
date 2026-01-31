# MVVM Architecture Validation

## Quick Start

```bash
# Run validation manually
./scripts/validate-mvvm-architecture-v2026-01-30.sh

# Runs automatically on git commit
git commit -m "Your changes"
```

## What It Detects

### ✅ Fully Automated (Error Level)

1. **Data Formatting in Views**
   - `.formatted()`, `.formattedAs()`, `.formattedAsLocalized()`
   - **Fix**: Move to ViewModel properties

2. **Date Formatting in Views**
   - `.formatted(date:`
   - **Fix**: Move to ViewModel properties

3. **Business Logic in Views**
   - `filter()`, `map()`, `reduce()`, `sorted()`, `Dictionary(grouping:)`
   - **Fix**: Move to ViewModel methods

4. **ViewModel Instantiation in Body**
   - `@StateObject private var viewModel = SomeViewModel()`
   - **Fix**: Use `init()` method pattern

5. **Direct Service Access**
   - `AppServices.live.`
   - **Fix**: Use `@Environment(\.appServices)`

### ⚠️ Warnings (Review Recommended)

1. **Missing ViewModel**
   - View has model properties but no ViewModel
   - **Fix**: Create corresponding ViewModel

2. **Direct Model Access**
   - View accesses model properties directly
   - **Fix**: Access via ViewModel properties

## Integration

The validation script is integrated into:
- ✅ Pre-commit hook (`scripts/pre-commit-hook-v2026-01-30.sh`)
- ✅ Git hooks (`.githooks/pre-commit`)
- ✅ SwiftLint rules (`.swiftlint.yml`)

## Documentation

See `Documentation/MVVM_VALIDATION_GUIDE.md` for complete details.



