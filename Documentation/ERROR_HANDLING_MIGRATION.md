# Error Handling Migration Guide

## Overview

This document describes the migration from direct `error.localizedDescription` usage to the centralized `AppError` pattern with proper error mapping.

## Why Migrate?

1. **Consistency**: All errors flow through `AppError` enum
2. **Localization**: Proper `LocalizedError` support via `errorDescription`
3. **Categorization**: Errors are properly categorized (validation, network, service, etc.)
4. **Maintainability**: Single source of truth for error mapping
5. **Architecture Compliance**: Follows cursor rules for error handling

## Migration Pattern

### Before (❌ FORBIDDEN)

```swift
func handleError(_ error: Error) {
    errorMessage = error.localizedDescription  // ❌ Direct usage
    showError = true
}
```

### After (✅ CORRECT)

```swift
func handleError(_ error: Error) {
    let appError = error.toAppError()  // ✅ Use shared extension
    errorMessage = appError.errorDescription ?? "An error occurred"
    showError = true
}
```

## Step-by-Step Migration

### Step 1: Import (if needed)

The `Error+AppError` extension is in `Shared/Utilities/Error+AppError.swift` and is automatically available.

### Step 2: Update Error Handling Methods

Replace direct `error.localizedDescription` usage with `error.toAppError()`:

```swift
// Old
func handleError(_ error: Error) {
    errorMessage = error.localizedDescription
    showError = true
}

// New
func handleError(_ error: Error) {
    let appError = error.toAppError()
    errorMessage = appError.errorDescription ?? "An error occurred"
    showError = true
}
```

### Step 3: Update AppError Methods

If you have methods that accept `AppError`, use `errorDescription` instead of `localizedDescription`:

```swift
// Old
func showError(_ error: AppError) {
    errorMessage = error.localizedDescription  // ❌
    showError = true
}

// New
func showError(_ error: AppError) {
    errorMessage = error.errorDescription ?? "An error occurred"  // ✅
    showError = true
}
```

### Step 4: Update Catch Blocks

In catch blocks, use the extension:

```swift
// Old
catch {
    errorMessage = "Failed: \(error.localizedDescription)"  // ❌
    showError = true
}

// New
catch {
    let appError = error.toAppError()
    errorMessage = appError.errorDescription ?? "Operation failed"  // ✅
    showError = true
}
```

## Examples from Updated ViewModels

### InvestmentsViewModel

```swift
func showError(_ error: AppError) {
    errorMessage = error.errorDescription ?? "An error occurred"
    showError = true
}

func handleError(_ error: Error) {
    let appError = error.toAppError()
    errorMessage = appError.errorDescription ?? "An error occurred"
    showError = true
}
```

### CustomerSupportDashboardViewModel

```swift
func handleError(_ error: Error) {
    let appError = error.toAppError()
    errorMessage = appError.errorDescription ?? "An error occurred"
    showError = true
}
```

## Migration Status

### ✅ Completed ViewModels (All Updated)

#### High Priority (User-Facing)
- [x] `InvestmentsViewModel` ✅
- [x] `CompletedInvestmentsViewModel` ✅
- [x] `TradesOverviewViewModel` ✅
- [x] `CustomerSupportDashboardViewModel` ✅
- [x] `FAQKnowledgeBaseViewModel` ✅
- [x] `CustomerSupportErrorHandler` ✅

#### Medium Priority
- [x] `SimplifiedSellOrderViewModel` ✅
- [x] `InvoiceViewModel` ✅
- [x] `InvestmentSummaryViewModel` ✅
- [x] `InvestorWatchlistViewModel` ✅
- [x] `InvestmentDetailViewModel` ✅
- [x] `RoundingDifferencesViewModel` ✅
- [x] `AuthenticationViewModel` ✅

#### Views
- [x] `CustomerSupportSettingsView` ✅
- [x] `MyTicketsView` ✅
- [x] `UserTicketDetailView` ✅
- [x] `LandingViewModel` ✅

**Migration Complete!** All ViewModels and Views now use the centralized `AppError` pattern.

## Shared Extension Details

The `Error+AppError` extension (`Shared/Utilities/Error+AppError.swift`) provides:

- Automatic mapping of `AppError` (returns as-is)
- Mapping of `CustomerSupportError` → `AppError`
- Mapping of `NetworkError` → `AppError`
- Mapping of `AuthError` → `AppError`
- Mapping of `ServiceError` → `AppError`
- Fallback for `LocalizedError` → `AppError.unknown`
- Fallback for unknown errors → `AppError.unknown`

## Testing

After migration, verify:
1. ✅ Build succeeds
2. ✅ Error messages display correctly
3. ✅ Error categorization works (validation vs service vs network)
4. ✅ Localization is preserved
5. ✅ No regressions in error handling

## Benefits

1. **Consistent Error Handling**: All ViewModels follow the same pattern
2. **Better User Experience**: Proper error messages with recovery suggestions
3. **Easier Debugging**: Errors are properly categorized
4. **Future-Proof**: Easy to add new error types to the mapping
5. **Architecture Compliance**: Follows cursor rules

## Questions?

If you encounter domain-specific errors that need mapping, add them to `Error+AppError.swift` following the existing pattern.
