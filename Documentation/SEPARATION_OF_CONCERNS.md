# Separation of Concerns Guidelines

## Overview

This document defines the separation of concerns principles for the FIN1 app and how they are enforced.

## Principles

### 1. Views = UI Only ✅

**Views should only contain:**
- UI layout and structure
- View modifiers (padding, colors, fonts)
- User interaction handlers (buttons, taps)
- Navigation presentation

**Views should NOT contain:**
- ❌ Service calls (`services.tradeService`, `services.invoiceService`)
- ❌ Business logic (calculations, data processing)
- ❌ Data transformations (filter, map, reduce, sorted)
- ❌ Async operations (except simple `Task { }` for ViewModel calls)
- ❌ Data formatting (use ViewModel properties instead)

### 2. ViewModels = Logic Coordination ✅

**ViewModels should:**
- Coordinate between Views and Services
- Handle business logic
- Transform data for display
- Manage state and loading states
- Call services and process results

**ViewModels should NOT:**
- ❌ Contain UI code (SwiftUI views)
- ❌ Directly access UI components
- ❌ Be instantiated in View body (must be in `init()`)

### 3. Services = Data & Network ✅

**Services should:**
- Handle network requests
- Manage data persistence
- Perform calculations
- Coordinate with external systems

**Services should NOT:**
- ❌ Contain ViewModels
- ❌ Have `@Published` properties (unless it's a service state)
- ❌ Directly manipulate UI

### 4. Models = Data Structures ✅

**Models should:**
- Define data structures
- Provide computed properties for data access
- Be pure data containers

**Models should NOT:**
- ❌ Contain business logic
- ❌ Make service calls
- ❌ Contain View code

## File Organization

### Correct Structure ✅

```
FIN1/Features/Trader/
├── Views/
│   ├── BuyOrderView.swift          ✅ View files
│   └── Components/
│       └── BuyConfirmationView.swift
├── ViewModels/
│   ├── BuyOrderViewModel.swift     ✅ ViewModel files
│   └── TradeDetailsViewModel.swift
├── Services/
│   ├── TradeService.swift          ✅ Service files
│   └── InvoiceService.swift
└── Models/
    ├── Trade.swift                 ✅ Model files
    └── Order.swift
```

### Incorrect Structure ❌

```
FIN1/Features/Trader/
├── Models/
│   ├── Trade.swift
│   └── BuyConfirmationView.swift   ❌ View in Models/
└── Views/
    ├── BuyOrderView.swift
    └── BuyOrderViewModel.swift     ❌ ViewModel in Views/
```

## Examples

### ✅ Correct: View with ViewModel

```swift
struct BuyOrderView: View {
    @StateObject private var viewModel: BuyOrderViewModel

    init(services: AppServices) {
        _viewModel = StateObject(wrappedValue: BuyOrderViewModel(services: services))
    }

    var body: some View {
        VStack {
            Text(viewModel.formattedPrice)  // ✅ ViewModel provides formatted data
            Button("Buy") {
                Task {
                    await viewModel.createOrder()  // ✅ ViewModel handles logic
                }
            }
        }
    }
}
```

### ❌ Incorrect: View with Direct Service Calls

```swift
struct BuyOrderView: View {
    @Environment(\.appServices) private var services  // ❌ Direct service access

    var body: some View {
        VStack {
            Text(price.formattedAsLocalizedCurrency())  // ❌ Formatting in View
            Button("Buy") {
                Task {
                    await services.tradeService.createOrder(...)  // ❌ Service call in View
                }
            }
        }
    }
}
```

### ✅ Correct: ViewModel Coordinates Logic

```swift
@MainActor
final class BuyOrderViewModel: ObservableObject {
    @Published var formattedPrice: String = ""
    private let tradeService: any TradeServiceProtocol

    init(tradeService: any TradeServiceProtocol) {
        self.tradeService = tradeService
        updateFormattedPrice()
    }

    func createOrder() async {
        // ✅ ViewModel handles service calls and business logic
        do {
            let order = try await tradeService.createOrder(...)
            // Process result...
        } catch {
            // Handle error...
        }
    }

    private func updateFormattedPrice() {
        formattedPrice = price.formattedAsLocalizedCurrency()  // ✅ Formatting in ViewModel
    }
}
```

## Enforcement

### Automated Checks

1. **Pre-commit Hook**: `validate-separation-of-concerns.sh`
   - Blocks commits with violations
   - Checks file organization
   - Detects service calls in Views

2. **SwiftLint**: Custom rules
   - `no_direct_service_access_in_view`
   - `no_data_formatting_in_view`
   - `no_business_logic_in_view`

3. **CI/CD**: Runs on every PR
   - Fails build if violations found
   - Prevents merge until fixed

4. **Danger**: PR review
   - Warns on service calls in Views
   - Fails PR if Views in wrong directory

## Common Violations & Fixes

### Violation: Service Call in View

**❌ Wrong:**
```swift
struct TradeView: View {
    @Environment(\.appServices) private var services

    var body: some View {
        Button("Load") {
            Task {
                let trades = await services.tradeService.getTrades()  // ❌
            }
        }
    }
}
```

**✅ Fix:**
```swift
struct TradeView: View {
    @StateObject private var viewModel: TradeViewModel

    var body: some View {
        Button("Load") {
            Task {
                await viewModel.loadTrades()  // ✅
            }
        }
    }
}

// ViewModel handles service call
@MainActor
final class TradeViewModel: ObservableObject {
    private let tradeService: any TradeServiceProtocol

    func loadTrades() async {
        let trades = await tradeService.getTrades()  // ✅
    }
}
```

### Violation: Business Logic in View

**❌ Wrong:**
```swift
struct TradeListView: View {
    let trades: [Trade]

    var body: some View {
        List(trades.filter { $0.isActive }.sorted { $0.date > $1.date }) {  // ❌
            TradeRow(trade: $0)
        }
    }
}
```

**✅ Fix:**
```swift
struct TradeListView: View {
    @StateObject private var viewModel: TradeListViewModel

    var body: some View {
        List(viewModel.sortedActiveTrades) {  // ✅
            TradeRow(trade: $0)
        }
    }
}

// ViewModel handles filtering and sorting
@MainActor
final class TradeListViewModel: ObservableObject {
    @Published var sortedActiveTrades: [Trade] = []

    func updateTrades(_ trades: [Trade]) {
        sortedActiveTrades = trades
            .filter { $0.isActive }
            .sorted { $0.date > $1.date }  // ✅
    }
}
```

## Summary

- ✅ **Views**: UI only, delegate to ViewModels
- ✅ **ViewModels**: Coordinate logic, call services, format data
- ✅ **Services**: Handle data/network operations
- ✅ **Models**: Pure data structures
- ✅ **File Organization**: Views in Views/, ViewModels in ViewModels/, etc.

All violations are automatically detected and prevented by pre-commit hooks, CI/CD, and PR reviews.

















