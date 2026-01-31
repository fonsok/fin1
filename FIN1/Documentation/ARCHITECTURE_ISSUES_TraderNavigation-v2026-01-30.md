# Architecture Issues: Trader Navigation & DRY Violations

## Problem Summary
The trader detail navigation implementation revealed multiple architectural issues that made debugging difficult and violated DRY, MVVM, and SwiftUI best practices.

## Issues Identified

### 1. **DRY Violation: Duplicated Code**
The same logic is duplicated across `DashboardTraderOverview` and `HitlistTableSection`:

- **`findTraderByID` method**: Duplicated in both views
- **`computeExpectancy` method**: Duplicated in both views
- **`handleWatchlistToggle` logic**: Identical implementation in both views
- **Sheet presentation with error fallbacks**: Nearly identical error handling views

**Impact**: Changes must be made in multiple places, increasing risk of bugs and inconsistencies.

### 2. **Service Method Not Utilized**
`TraderDataServiceProtocol` already has:
```swift
func getTrader(by id: String) -> MockTrader?
```

But views implement their own `findTraderByID` method instead of using the service.

**Impact**: Business logic leaks into views, violating MVVM separation of concerns.

### 3. **Business Logic in Views**
`computeExpectancy` is business logic that calculates trading metrics but lives in View code.

**Impact**:
- Not testable in isolation
- Cannot be reused by other features
- Violates MVVM principle (Views should only handle presentation)

**Should be in**: `TraderDataService` or a dedicated `TradingStatisticsService`

### 4. **Missing Navigation Helper Pattern**
The codebase has `DocumentNavigationHelper` for centralized document navigation, but no equivalent for trader navigation.

**Current Pattern** (Good):
```swift
DocumentNavigationHelper.sheetView(for: document, appServices: appServices)
```

**Missing Pattern** (Should exist):
```swift
TraderNavigationHelper.sheetView(for: traderID, appServices: appServices)
```

**Impact**: Each view reinvents trader navigation logic instead of using a shared helper.

### 5. **SwiftUI Anti-Pattern: State Timing Issues**
Using `.sheet(isPresented:)` with two separate state variables causes timing issues:

```swift
// ❌ PROBLEMATIC
@State private var selectedTrader: String?
@State private var showTraderDetails = false

.sheet(isPresented: $showTraderDetails) {
    if let traderID = selectedTrader { ... }
}
```

**Problem**: Sheet content evaluates before state updates complete, causing bugs.

**Solution**: Use `.sheet(item:)` with Identifiable wrapper:
```swift
// ✅ CORRECT
@State private var selectedTraderID: TraderIDItem?

.sheet(item: $selectedTraderID) { traderIDItem in
    // Content guaranteed to have valid ID
}
```

### 6. **Inconsistent Navigation Patterns**
- `DashboardTraderOverview`: Uses `.sheet(isPresented:)` with complex conditionals
- `HitlistTableSection`: Uses `.sheet(item:)` with Identifiable wrapper

**Impact**: Inconsistent behavior, harder to maintain, one pattern works while the other fails.

## Proposed Solution

### Step 1: Create TraderNavigationHelper (Follow Existing Pattern)
```swift
// FIN1/Shared/Components/Navigation/TraderNavigationHelper.swift
struct TraderNavigationHelper {
    @ViewBuilder
    static func sheetView(
        for traderID: String,
        appServices: AppServices
    ) -> some View {
        if let trader = appServices.traderDataService.getTrader(by: traderID) {
            NavigationStack {
                TraderDetailsView(trader: trader)
            }
        } else {
            TraderNotFoundView(traderID: traderID)
        }
    }
}
```

### Step 2: Move Business Logic to Service
```swift
// In TraderDataService or TradingStatisticsService
func computeExpectancy(for trader: MockTrader) -> Double {
    // Business logic implementation
}
```

### Step 3: Standardize on `.sheet(item:)` Pattern
Both views should use:
```swift
@State private var selectedTraderID: TraderIDItem?

.sheet(item: $selectedTraderID) { traderIDItem in
    TraderNavigationHelper.sheetView(
        for: traderIDItem.id,
        appServices: appServices
    )
}
```

### Step 4: Extract Error Views
Create reusable `TraderNotFoundView` component.

## Benefits of Refactoring

1. **Single Source of Truth**: Navigation logic in one place
2. **Easier Testing**: Business logic in services can be unit tested
3. **Consistency**: All trader navigation uses same pattern
4. **Maintainability**: Changes only needed in one place
5. **Reliability**: `.sheet(item:)` pattern eliminates timing bugs

## Migration Status

### ✅ Completed
1. ✅ **Fixed `DashboardTraderOverview`** to use `.sheet(item:)` pattern
2. ✅ **Created `TraderNavigationHelper`** (eliminates DRY violation)
3. ✅ **Removed `computeExpectancy`** (dead code - not displayed in UI)
4. ✅ **Replaced `findTraderByID`** with `service.getTrader(by:)` in both views
5. ✅ **Extracted error views** to `TraderNotFoundView` component

### 📋 Future Improvements (Optional)
- Consider creating a shared `TraderSelectionViewModel` if watchlist logic becomes more complex
- Add unit tests for `TraderNavigationHelper`

