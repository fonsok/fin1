---
alwaysApply: true
---

# FIN1 Architecture & Coding Standards

This is the main architecture and coding standards document for FIN1. All other rule files in this directory complement these core rules.

## Architecture & DI

- Use MVVM. Views bind to ViewModels; ViewModels depend on protocols, not concrete services.
- Composition root is `FIN1/FIN1App.swift` via `AppServices` and `Environment(\.appServices)`.
- Do not use `.shared` singletons outside the composition root, except preview-only fallbacks.
- ViewModels must not default to singletons in initializers. Require explicit protocol arguments.
- Views must not import Services directly. Inject via ViewModels only.
- Centralize role-based navigation in `MainTabView.RoleRouter`.
- Use centralized error handling via `AppError` enum for consistent error management.
- Prefer async/await patterns over completion handlers for service calls.
- Use Coordinator pattern for complex navigation flows (e.g., `SecuritiesSearchCoordinator`).
- Implement Repository pattern for data access abstraction.
- Use Factory pattern for complex object creation in services.

### DI Pattern: reconfigure(with: AppServices)

- ViewModels SHOULD expose a single-container reconfiguration API: `reconfigure(with services: AppServices)`.
- Rationale: prevents parameter drift and ensures all required services are refreshed together when the environment changes.
- Required dependencies SHOULD be non-optional in initializers. Avoid runtime fallbacks for missing services.
- Legacy multi-argument `reconfigure(...)` overloads MUST be marked `@available(*, deprecated)` and removed after migrating callers.

## Service Architecture

- Each feature should have its own service layer: `Features/<Feature>/Services/`
- Services implement `ServiceLifecycle` protocol for start/stop/reset lifecycle management.
- Service protocols define contracts: `Features/<Feature>/Services/<Feature>ServiceProtocol.swift`
- Service implementations: `Features/<Feature>/Services/<Feature>Service.swift`
- Models are extracted to: `Features/<Feature>/Models/` (not embedded in ViewModels).
- All services are registered in `AppServices` and injected via environment.
- Services should be stateless and thread-safe.
- Use async/await for all service methods, avoid completion handlers.
- Implement proper error propagation with `Result<T, AppError>` types.
- Add service health monitoring and circuit breaker patterns.

### Backend Integration Patterns

**REQUIRED**: All backend integrations must follow a mock-first, protocol-based approach to enable easy swapping of implementations.

#### Parse Server Integration

- **REQUIRED**: New features MUST start with Parse Server mock implementation
- **REQUIRED**: Design services to be replaceable with external BaaS/Compliance services
- **REQUIRED**: Use protocol-based services (e.g., `PaymentServiceProtocol`, `BaaSServiceProtocol`) for abstraction
- **REQUIRED**: Parse Cloud Functions for business logic, not client-side calculations
- **REQUIRED**: All Parse Server interactions MUST go through service layer, never directly from ViewModels
- **FORBIDDEN**: Hardcoding Parse Server classes (e.g., `PFObject`) in ViewModels or Views

#### Mock-First Development

- **REQUIRED**: New payment/trading features MUST work with Parse Server mocks first
- **REQUIRED**: Services MUST be designed to swap Parse implementation for BaaS later without changing ViewModels
- **REQUIRED**: Mock data MUST be stored in Parse Server during development (not hardcoded in app)
- **FORBIDDEN**: Hardcoding external service dependencies - use dependency injection
- **REQUIRED**: Service protocols MUST abstract away backend implementation details

**Example Pattern**:
```swift
// ✅ CORRECT: Protocol-based service that can swap implementations
protocol PaymentServiceProtocol {
    func processDeposit(amount: Double) async throws -> Transaction
    func processWithdrawal(amount: Double) async throws -> Transaction
}

// Parse implementation (mock for MVP)
final class ParsePaymentService: PaymentServiceProtocol {
    // Uses Parse Server for now, can be swapped for BaaS later
}

// Future BaaS implementation (when ready)
final class BaaSPaymentService: PaymentServiceProtocol {
    // Uses Solaris/Basikon BaaS API
}

// ViewModel doesn't change when swapping implementations
final class PaymentViewModel: ObservableObject {
    private let paymentService: PaymentServiceProtocol // Protocol, not concrete type
    
    init(paymentService: PaymentServiceProtocol) {
        self.paymentService = paymentService
    }
}
```

#### Backend Service Location

- **Parse Server**: `backend/parse-server/` - Main backend API
- **Cloud Functions**: `backend/parse-server/cloud/` - Business logic
- **Docker Setup**: `docker-compose.yml` - Local development environment
- **Documentation**: `backend/README.md` - Backend setup and architecture

#### BaaS Integration (Future)

- **REQUIRED**: When integrating BaaS (e.g., Solaris, Basikon), create new service implementation
- **REQUIRED**: Keep Parse Server implementation for fallback/testing
- **REQUIRED**: Use feature flags to switch between implementations
- **REQUIRED**: All BaaS integrations MUST follow same protocol pattern
- **REQUIRED**: Reference `Documentation/BAAS_EVALUATION.md` for integration guidelines

**BaaS Integration Pattern**:
```swift
// ✅ CORRECT: Service factory that can switch implementations
final class AppServices {
    let paymentService: PaymentServiceProtocol
    
    static var live: AppServices {
        let useBaaS = ConfigurationService.shared.shouldUseBaaS()
        
        return AppServices(
            paymentService: useBaaS 
                ? BaaSPaymentService() 
                : ParsePaymentService()
        )
    }
}
```

### Calculation Services Pattern

**REQUIRED**: For complex business calculations (e.g., collection bills, profit calculations, ROI), use dedicated calculation services:

- **Location**: `Features/<Feature>/Services/<Feature>CalculationService.swift`
- **Protocol**: `Features/<Feature>/Services/<Feature>CalculationServiceProtocol.swift`
- **DTOs**: Define input/output DTOs for clear contracts: `Features/<Feature>/Services/<Feature>CalculationDTOs.swift`
- **Validation**: Include input validation in the service (not in ViewModels)
- **Data Source Hierarchy**: Document and enforce authoritative data sources
- **Error Handling**: Use throwing methods with specific error types
- **Testing**: Comprehensive unit tests covering all scenarios and edge cases

#### Single Source of Truth for Financial Calculations

**CRITICAL**: Financial values (commission, fees, profit, etc.) must NEVER be calculated inline or duplicated across multiple locations. This prevents discrepancies between stored values and displayed values.

**FORBIDDEN**:
```swift
// ❌ Inline calculation - prone to formula drift
let commission = allocatedAmount * (roi / 100.0) * rate

// ❌ Different formula in another file
let commission = grossProfit * rate
```

**REQUIRED**:
```swift
// ✅ Always use the centralized calculation service
let commission = try await commissionCalculationService.calculateCommissionForInvestor(
    investmentId: investmentId,
    tradeId: tradeId,
    commissionRate: rate
)
```

**Authoritative Calculation Services**:
| Calculation | Service | Method |
|-------------|---------|--------|
| Commission | `CommissionCalculationService` | `calculateCommissionForInvestor()` |
| Gross Profit | `InvestorGrossProfitService` | `getGrossProfit()` |
| Collection Bill | `InvestorCollectionBillCalculationService` | `calculateCollectionBill()` |

**When creating invoices/documents**: Use the same service that will be used to display the data. This ensures stored values exactly match displayed values.

**Pattern Example**:
```swift
// Protocol
protocol InvestorCollectionBillCalculationServiceProtocol {
    func calculateCollectionBill(input: InvestorCollectionBillInput) throws -> InvestorCollectionBillOutput
    func validateInput(_ input: InvestorCollectionBillInput) -> ValidationResult
}

// DTOs
struct InvestorCollectionBillInput { /* ... */ }
struct InvestorCollectionBillOutput { /* ... */ }

// Service
final class InvestorCollectionBillCalculationService: InvestorCollectionBillCalculationServiceProtocol {
    func calculateCollectionBill(input: InvestorCollectionBillInput) throws -> InvestorCollectionBillOutput {
        // Validate first
        let validation = validateInput(input)
        guard validation.isValid else {
            throw CollectionBillCalculationError.validationFailed(...)
        }
        // Calculate and return
    }
}
```

**Benefits**:
- ✅ Single source of truth for calculations
- ✅ Easier to test independently
- ✅ Clear separation of business logic from display logic
- ✅ Enforced data source hierarchy
- ✅ Reusable across multiple ViewModels

## Naming Conventions

- **Services**: Use "Service" suffix for business logic/data operations (e.g., `UserService`, `InvestmentService`, `NotificationService`)
- **Repositories**: Use "Repository" suffix for data persistence (e.g., `SavedSecuritiesFiltersRepository`, `UserPreferencesRepository`)
- **Stores**: Use "Store" suffix for state management (e.g., `TradingStateStore`, `AppStateStore`)
- **Coordinators**: Use "Coordinator" suffix for orchestration/coordination (e.g., `ServiceLifecycleCoordinator`, `NavigationCoordinator`, `SecuritiesSearchCoordinator`)
- **Providers**: Use "Provider" suffix for data/configuration providers (e.g., `TabConfigurationProvider`, `ThemeProvider`)
- **Configurators**: Use "Configurator" suffix for configuration/setup (e.g., `TabBarAppearanceConfigurator`, `AppConfigurator`)
- **Utilities**: Use "Utility" suffix for static utility functions (e.g., `FileSystemUtility`, `DateFormatterUtility`)
- **FORBIDDEN**: Avoid "Manager" suffix - use more specific names that indicate single responsibility
  - "Manager" is vague and doesn't clearly indicate what the class manages
  - Prefer specific suffixes: Service, Repository, Store, Coordinator, Provider, Configurator, Utility
  - **Rationale**: Modern Swift best practices favor descriptive names that clearly indicate a class's single responsibility
  - **Migration**: Existing "Manager" classes should be renamed to appropriate suffixes (see `Documentation/MANAGER_NAMING_ANALYSIS.md`)

### Avoid Redundant Naming (Swift API Design Guidelines)

**FORBIDDEN**: Names that repeat the suffix within the domain name, creating redundancy.

Per [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/): *"Omit needless words. Every word in a name should convey salient information."*

**Common Violation Pattern**: `<Domain>Service` where Domain already contains "Service"

| ❌ Bad (Redundant) | ✅ Good (Clear) | Reason |
|-------------------|-----------------|--------|
| `CustomerServiceService` | `CustomerSupportService` | "Service" appears twice |
| `ServiceManagementService` | `ServiceOrchestrator` | "Service" appears twice |
| `NotificationServiceService` | `NotificationService` | Avoid doubling suffix |
| `AuthServiceService` | `AuthenticationService` | Expand abbreviation, single suffix |

**How to Fix**:
1. **Rename the domain**: `CustomerService` → `CustomerSupport`, `Support`, `CustomerCare`
2. **Use a different suffix**: `ServiceManagement` → `ServiceOrchestrator`, `ServiceCoordinator`
3. **Expand abbreviations**: `AuthService` → `AuthenticationService`

**Detection**: Before naming a class, check if the domain name already contains the intended suffix. If so, choose an alternative domain name or suffix.

## Performance & Memory Management

- Use `@StateObject` for ViewModels, `@ObservedObject` for injected dependencies.
- Implement lazy loading for large datasets.
- Use `@Published` sparingly - only for UI-bound properties.
- Avoid retain cycles with `[weak self]` in closures.
- Use `Task` for async operations, not `DispatchQueue`.
- Keep functions under 50 lines.
- Maximum 3 levels of nesting.

### File Size Limits (Tiered by Type)

**General Rule**: All classes must be ≤ 400 lines.

Smaller files enforce better separation of concerns, easier code reviews, and reduced merge conflicts.

| File Type | Max Lines | Rationale |
|-----------|-----------|-----------|
| **Models** (`struct`) | 200 | Data structures should be simple and focused |
| **Views** (SwiftUI) | 300 | UI should be componentized into smaller views |
| **ViewModels** | 400 | Business logic needs room, but should delegate to services |
| **Services** | 400 | Core logic, but should use composition pattern |
| **Coordinators** | 300 | Orchestration should be thin, delegating to services |
| **Utilities/Helpers** | 200 | Single-purpose helpers should be small |
| **Protocols** | 100 | Interface definitions should be concise |
| **Extensions** | 150 | Focused functionality extensions |
| **All Classes** | **400** | **General maximum for all class types** |

**Refactoring Strategy for Large Files:**
1. **Extract subcomponents** - Break Views into smaller reusable components
2. **Extract services** - Move business logic from ViewModels to dedicated services
3. **Use composition** - Combine smaller services instead of one large service
4. **Split by responsibility** - One file = one clear responsibility

## Class vs Struct Best Practices

**General Swift Principles:**
- **Prefer structs by default** for most data models and value types
- **Use classes** when you need reference semantics, shared mutable state, or inheritance
- **Structs are value types**: Copied on assignment, each variable has its own independent copy
- **Classes are reference types**: Shared references, changes affect all references
- **Structs are safer and more performant** in many cases due to value semantics
- Swift standard library types (String, Array, Dictionary) are structs

**SwiftUI/MVVM-Specific Requirements:**

- **Models**: Always use `struct` for data models (Invoice, Order, Trade, Investment, User, Document, etc.)
  - Value semantics are appropriate for data that should be copied
  - Structs are more efficient for immutable data

- **ViewModels**: **ALWAYS use `class` with `ObservableObject`** (required for SwiftUI observation)
  - ViewModels need reference semantics to maintain state across view updates
  - `ObservableObject` protocol requires reference types (classes)
  - SwiftUI's observation system needs reference identity to track the same instance
  - **CRITICAL**: ViewModels cannot be structs in SwiftUI

- **Services**: Use `class` for services that maintain state or need reference semantics
  - Services typically need to be injected as shared instances
  - Stateful services with `@Published` properties must be classes with `ObservableObject`
  - Stateless services can be classes (for DI/shared instances) or structs (for utilities with static methods)

- **Coordinators**: Use `class` for coordinators that manage lifecycle or navigation state
  - Coordinators need reference semantics for state management

- **Repositories**: Use `class` with `ObservableObject` when state observation is needed
  - Repositories that expose `@Published` properties must be classes
  - Required for SwiftUI observation of data changes

- **Utility Services**: Use `struct` with static methods for stateless utilities (e.g., `UserValidationService`)
  - No state, no observation needed - perfect use case for struct

- **Container Types**: Use `struct` for value containers (e.g., `AppServices`)
  - Value semantics appropriate for dependency injection containers

- **MANDATORY**: Mark classes as `final` when inheritance is not needed
  - Improves performance (enables static dispatch)
  - Makes intent clear (no subclassing intended)
  - Prevents accidental inheritance
  - **REQUIRED**: All ViewModels, Services, Coordinators, and Repositories should be `final` unless specifically designed for inheritance
  - **EXCEPTION**: Only omit `final` if the class is part of an inheritance hierarchy (base classes, abstract classes)

**Decision Tree:**
1. Need SwiftUI observation (`ObservableObject`, `@Published`)? → **Use `class`** (required)
2. Need reference semantics (shared state, DI, lifecycle)? → **Use `class`** (preferred)
3. Data model or value container? → **Use `struct`** (preferred)
4. Stateless utility (static methods only)? → **Use `struct`** (preferred)
5. Always mark classes as `final` unless inheritance is specifically needed

## SwiftUI Observation & Lifecycle

- **CRITICAL**: Never create ViewModel instances in view body or navigation closures.
- Use `@StateObject` for ViewModels owned by the view (created in `init` or `body`).
- Use `@ObservedObject` for ViewModels passed from parent views.
- For navigation destinations, create wrapper views with `@StateObject` ViewModels.
- Always test that `@Published` property changes trigger view updates.
- Use `.task` instead of `.onAppear` for async data loading.
- Avoid creating objects in view body that break SwiftUI's observation system.
- When debugging observation issues, add logging to verify same object instance is being observed.
- Use `@State` for simple local state, `@StateObject` for complex state management.

**Navigation Pattern Example:**
```swift
// ❌ BAD: Creates new ViewModel on every navigation
.navigationDestination(item: $selectedItem) { item in
    DetailView(viewModel: DetailViewModel(item: item))
}

// ✅ GOOD: Use wrapper with @StateObject
.navigationDestination(item: $selectedItem) { item in
    DetailViewWrapper(item: item)
}

struct DetailViewWrapper: View {
    let item: Item
    @StateObject private var viewModel: DetailViewModel

    init(item: Item) {
        self.item = item
        self._viewModel = StateObject(wrappedValue: DetailViewModel(item: item))
    }

    var body: some View {
        DetailView(viewModel: viewModel)
    }
}
```

## Lifecycle & Telemetry

- On `scenePhase == .active`, preload user notifications/documents and start `ServiceLifecycle` services.
- Track telemetry events (e.g., `app_active`) and wire error reporting hooks in services.

## Testing Structure

- All unit tests live under `FIN1Tests/`. Do not create nested `FIN1/FIN1Tests/`.
- Add/adjust tests for:
  - New/changed ViewModels (state, outputs, navigation decisions).
  - Role-based navigation via `RoleRouter`.
  - Lifecycle/telemetry behavior if touched.
- Use the Xcode Test Plan `FIN1/FIN1.xctestplan` when running locally.
- Use `@testable import FIN1` for testing internal APIs.
- Mock all external dependencies in tests.
- Test error scenarios and edge cases.
- Use `XCTestExpectation` for async testing.
- Aim for 80%+ code coverage on critical paths.

## Error Handling

- Use `AppError` enum for all error types (validation, network, authentication, service).
- ViewModels should handle errors gracefully and provide user-friendly messages.
- Services should throw specific error types that map to `AppError` cases.
- Avoid generic error messages; use localized descriptions from `AppError`.
- **REQUIRED**: ViewModels must map domain-specific errors (e.g., `CustomerSupportError`, `AuthError`) to `AppError` using a `mapToAppError()` helper method.
- **REQUIRED**: Use `AppError.errorDescription` (which implements `LocalizedError`) instead of generic `error.localizedDescription` for proper localization support.
- **FORBIDDEN**: Direct use of `error.localizedDescription` without mapping to `AppError` first.

### Error Mapping Pattern

**REQUIRED**: ViewModels should implement a `mapToAppError()` method to convert domain-specific errors to `AppError`:

```swift
// ✅ CORRECT: Map errors to AppError
private func mapToAppError(_ error: Error) -> AppError {
    // If already an AppError, return it
    if let appError = error as? AppError {
        return appError
    }

    // Map domain-specific errors
    if let domainError = error as? DomainSpecificError {
        switch domainError {
        case .permissionDenied:
            return .service(.permissionDenied)
        case .notFound:
            return .service(.dataNotFound)
        // ... map all cases
        }
    }

    // Fallback for unknown errors
    return .unknown(error.localizedDescription)
}

// In catch block:
catch {
    let appError = mapToAppError(error)
    errorMessage = appError.errorDescription ?? "Operation failed"
}
```

**❌ FORBIDDEN**: Generic error handling without mapping:
```swift
catch {
    errorMessage = "Failed: \(error.localizedDescription)" // ❌
}
```

## Security & Data Protection

- Never log sensitive data (passwords, tokens, personal info).
- Use secure storage for sensitive data (Keychain).
- Validate all user inputs before processing.
- Implement proper authentication state management.
- Use HTTPS for all network requests.

## Documentation

- Document all public APIs with Swift DocC comments.
- Keep README.md updated with setup instructions.
- Document architectural decisions in ADR (Architecture Decision Records).
- Investor-facing accounting artifacts (Collection Bills, statements, investment sheets) **must**
  - list every individual fee pulled from invoices (order, exchange, foreign costs, etc.); aggregating multiple fees into a single display line is prohibited unless accounting rules explicitly change.
  - derive gross profit/ROI from actual trade + invoice data (buy/sell amounts and fees). Never reverse-calculate gross numbers from net profit or cached percentages.
  - have regression tests covering the above. Removing fee detail or bypassing trade-based ROI should fail tests.
  - use dedicated calculation services (not inline calculations in ViewModels). See "Calculation Services Pattern" in Service Architecture section.
  - enforce data source hierarchy: Investment.amount (capital) → Trade.entryPrice → Invoice (fees/prices). Document hierarchy in service.
- Use TODO comments for temporary workarounds.
- Document complex business logic with inline comments.
- Use `// MARK:` for code organization.

## Code Quality Metrics

- Use meaningful variable and function names.
- Add documentation for public APIs.
- Use `// MARK:` for code organization.
- Keep functions under 50 lines.
- Follow tiered file size limits (see "File Size Limits" section above).
- Maximum 3 levels of nesting.

## Navigation & UI Standards

- **MANDATORY**: Use `NavigationStack` for all navigation containers.
- **FORBIDDEN**: Never use deprecated `NavigationView` - migration is complete.
- Use `NavigationLink(value:)` + `navigationDestination` for programmatic navigation.
- Use `.sheet()` only for modals, forms, and temporary content.
- Never use `.sheet()` for navigation that should maintain context.

## Guardrails (fail PRs if violated)

- **No failed builds**: Must achieve "BUILD SUCCEEDED" before committing - fix all build errors and retry until successful.
- No `.shared` in non-root production code.
- No default singleton parameters in ViewModel initializers.
- No tests outside `FIN1Tests/`.
- No generic error handling; use `AppError` enum.
- No functions over 50 lines.
- **No files exceeding tiered limits**: Models ≤200, Views ≤300, ViewModels/Services ≤400 lines. **All classes must be ≤ 400 lines.**
- No more than 3 levels of nesting.
- **No ViewModel creation in view body or navigation closures** (use wrapper views with `@StateObject`).
- **No object creation in view body** that breaks SwiftUI observation.
- **No fixed UI values**: No `.font(.title)`, `VStack(spacing: 16)`, `.cornerRadius(12)`, etc.
- **No legacy design patterns**: All UI must use `ResponsiveDesign` system.
- **No NavigationView**: All navigation must use `NavigationStack` (migration complete).
- **No business logic in Views**: No filtering, grouping, calculations, or data transformations in View computed properties.
- **No data processing in Views**: All data processing must be in ViewModels (Dictionary(grouping:), filter(), map(), reduce(), calendar operations).
- **No calculation logic in ViewModels**: Complex calculations (collection bills, profit, ROI) must use dedicated calculation services, not inline calculations.
- **No duplicate calculation code**: Calculation logic must be in a single service, not duplicated across ViewModels or aggregators.
- **No non-final classes**: All ViewModels, Services, Coordinators, and Repositories must be marked `final` unless part of an inheritance hierarchy.
- **No classes for data models**: All data models (Invoice, Order, Trade, etc.) must be `struct`, not `class`.
- **No "Manager" suffix**: Avoid "Manager" in class/file names - use specific suffixes (Service, Repository, Store, Coordinator, Provider, Configurator, Utility) that indicate single responsibility.
- **No redundant naming**: Avoid names where the domain repeats the suffix (e.g., `CustomerServiceService`). Per Swift API Guidelines: "Omit needless words."
- **No DRY violations**: Magic numbers, percentages, rates, and repeated strings must be defined as constants in `CalculationConstants` or appropriate location. Same value appearing in multiple files is a violation.

## MVVM Architecture Enforcement

- **FORBIDDEN**: `@StateObject private var viewModel = SomeViewModel()` in view body
- **REQUIRED**: `@StateObject private var viewModel: SomeViewModel` with `init()` method
- **FORBIDDEN**: Services with `@Published var viewModel = SomeViewModel()` properties
- **REQUIRED**: ViewModels managed by Views, not Services
- **FORBIDDEN**: `private init()` in services - must be `init()` for proper DI
- **REQUIRED**: All services instantiated in `AppServices` composition root
- **FORBIDDEN**: Direct service imports in Views - use `@Environment(\.appServices)`
- **REQUIRED**: Service protocols for all dependencies, not concrete types

## MVVM Business Logic Separation

- **FORBIDDEN**: Business logic in Views (filtering, grouping, calculations, data transformations)
- **REQUIRED**: All data processing in ViewModels
- **FORBIDDEN**: Complex computed properties in Views that process data (Dictionary(grouping:), filter(), map(), reduce(), calendar calculations)
- **REQUIRED**: Views only bind to ViewModel @Published properties
- **FORBIDDEN**: Data transformations, date formatting, or calendar operations in View computed properties
- **REQUIRED**: All transformations delegated to ViewModel methods or computed properties
- **FORBIDDEN**: Views directly processing model arrays (e.g., `trader.recentTrades.filter { ... }`)
- **REQUIRED**: ViewModels expose processed data via @Published properties
- **FORBIDDEN**: View computed properties that perform filtering, sorting, or grouping operations
- **REQUIRED**: ViewModels handle all data processing and expose ready-to-display data

## Service Architecture Enforcement

- **FORBIDDEN**: `static let shared = ServiceName()` outside composition root
- **REQUIRED**: All services created as instances in `AppServices`
- **FORBIDDEN**: Services depending on other services via `.shared`
- **REQUIRED**: Service dependencies injected via constructor
- **FORBIDDEN**: Services with ViewModel properties
- **REQUIRED**: Services focus on data/business logic only
- **FORBIDDEN**: `ObservableObject` services without proper lifecycle management
- **REQUIRED**: Services implement `ServiceLifecycle` protocol
- **FORBIDDEN**: "Manager" suffix in class/file names - use specific suffixes (Service, Repository, Store, Coordinator, Provider, Configurator, Utility)
- **REQUIRED**: Class names must clearly indicate single responsibility with appropriate suffix

## SwiftUI Observation Enforcement

- **FORBIDDEN**: Creating ViewModels in `.navigationDestination` closures
- **REQUIRED**: Use wrapper views with `@StateObject` for navigation
- **FORBIDDEN**: `@StateObject` with direct instantiation in property declaration
- **REQUIRED**: `@StateObject` with type declaration and `init()` method
- **FORBIDDEN**: Accessing `@Published` properties without proper observation
- **REQUIRED**: Use `@ObservedObject` for injected ViewModels
- **FORBIDDEN**: Creating objects in view body that break observation
- **REQUIRED**: All object creation in `init()` or computed properties

## Dependency Injection Enforcement

- **FORBIDDEN**: `AppServices.live.serviceName` in ViewModels
- **REQUIRED**: Inject services via constructor parameters
- **FORBIDDEN**: Hardcoded service dependencies in ViewModels
- **REQUIRED**: Use protocol types for all service dependencies
- **FORBIDDEN**: Service singletons in ViewModel initializers
- **REQUIRED**: Explicit service injection in all ViewModel constructors
- **FORBIDDEN**: Direct service access in Views
- **REQUIRED**: Access services via `@Environment(\.appServices)`

## Code Quality Enforcement

- **FORBIDDEN**: Missing `category` and `strike` parameters in OrderBuy/OrderSell
- **REQUIRED**: All model initializers must include all required parameters
- **FORBIDDEN**: Incomplete model initializations in tests
- **REQUIRED**: Complete model setup for all test scenarios
- **FORBIDDEN**: Services without proper error handling
- **REQUIRED**: All services must use `AppError` for error propagation
- **FORBIDDEN**: ViewModels using `error.localizedDescription` directly without mapping to `AppError`
- **REQUIRED**: ViewModels must implement `mapToAppError()` helper to convert domain-specific errors to `AppError`
- **FORBIDDEN**: Missing notification posting in authentication state changes
- **REQUIRED**: Post `NotificationCenter` events for state changes

## Real-World Examples (Based on Fixed Violations)

**❌ WRONG - ViewModel Creation in View Body:**
```swift
struct SomeView: View {
    @StateObject private var viewModel = SomeViewModel() // ❌ FORBIDDEN
}
```

**✅ CORRECT - ViewModel Creation in Init:**
```swift
struct SomeView: View {
    @StateObject private var viewModel: SomeViewModel

    init() {
        self._viewModel = StateObject(wrappedValue: SomeViewModel())
    }
}
```

**❌ WRONG - Service with ViewModel Property:**
```swift
class SomeService: ObservableObject {
    @Published var viewModel = SomeViewModel() // ❌ FORBIDDEN
}
```

**✅ CORRECT - Service without ViewModel:**
```swift
class SomeService: ObservableObject {
    // Services handle data/business logic only
    @Published var data: [SomeModel] = []
}
```

**❌ WRONG - Singleton Service Usage:**
```swift
class SomeViewModel: ObservableObject {
    private let service = SomeService.shared // ❌ FORBIDDEN
}
```

**✅ CORRECT - Injected Service:**
```swift
class SomeViewModel: ObservableObject {
    private let service: SomeServiceProtocol

    init(service: SomeServiceProtocol) {
        self.service = service
    }
}
```

**❌ WRONG - Business Logic in View:**
```swift
struct SomeView: View {
    let trader: MockTrader

    private var groupedData: [Data] {
        // ❌ FORBIDDEN: Complex data processing in View
        let filtered = trader.recentTrades.filter { $0.date >= cutoffDate }
        return Dictionary(grouping: filtered) { ... }
            .map { ... }
            .sorted { ... }
    }
}
```

**✅ CORRECT - Business Logic in ViewModel:**
```swift
// ViewModel
class SomeViewModel: ObservableObject {
    @Published var groupedData: [Data] = []

    func processData() {
        // ✅ Business logic belongs in ViewModel
        let filtered = trader.recentTrades.filter { $0.date >= cutoffDate }
        groupedData = Dictionary(grouping: filtered) { ... }
            .map { ... }
            .sorted { ... }
    }
}

// View
struct SomeView: View {
    @StateObject private var viewModel: SomeViewModel

    var body: some View {
        // ✅ View only binds to ViewModel property
        ForEach(viewModel.groupedData) { ... }
    }
}
```

## SwiftUI Debugging

- When `@Published` properties don't trigger view updates, add logging to verify:
  - Same ViewModel instance is being observed
  - Properties are actually being set
  - View body is re-evaluating after changes
- Use `let _ = print("...")` in view body to track rendering
- Test navigation flows to ensure ViewModels persist correctly
- Verify `.task` vs `.onAppear` timing for async operations

## Build Retry Policy

- **CRITICAL**: Before committing, build must succeed - retry builds until all errors fixed and "BUILD SUCCEEDED" achieved
- When a build fails: Analyze errors, fix compilation issues, address warnings (treat as errors), then rebuild
- **Never commit code that doesn't build successfully**
- During development: You can make iterative changes, but verify build succeeds before committing or moving to new tasks

## Local Commands

- Lint format: `swiftformat . --lint`
- SwiftLint: `swiftlint --strict`
- Format code: `swiftformat .`
- Build (sim): `xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build`
- Test (sim): `xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test`
- Check for memory leaks: `xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -enableAddressSanitizer YES build`
- Run performance tests: `xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -enableCodeCoverage YES test`

