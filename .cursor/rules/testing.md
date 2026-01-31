---
alwaysApply: true
---

# Testing Rules & Best Practices

## Overview

This document defines testing standards, mocking patterns, and best practices for the FIN1 codebase. All tests should follow these patterns for consistency and maintainability.

## Test Structure

### Location
- **All unit tests**: `FIN1Tests/` directory
- **All integration tests**: `FIN1Tests/` directory (with `Integration` suffix)
- **All UI tests**: `FIN1UITests/` directory
- **DO NOT** create nested `FIN1/FIN1Tests/` directories

### Test Organization
- One test file per ViewModel/Service/Repository
- Test files should mirror source file structure
- Use `@testable import FIN1` for testing internal APIs
- Use Xcode Test Plan `FIN1/FIN1.xctestplan` when running locally

## Mocking Patterns

### ✅ REQUIRED: Closure-Based Mocking Pattern

**MANDATORY**: All mocks must use closure-based behavior handlers instead of multiple configuration properties.

#### Pattern

```swift
class MockService: ServiceProtocol {
    // Behavior closures (not configuration properties)
    var methodHandler: ((Parameters) async throws -> ReturnType)?

    func method(_ params: Parameters) async throws -> ReturnType {
        if let handler = methodHandler {
            return try await handler(params)
        } else {
            // Sensible default behavior (no errors thrown)
            return defaultValue
        }
    }
}
```

#### ✅ CORRECT: Closure-Based Mock

```swift
// Mock
class MockInvoiceService: InvoiceServiceProtocol {
    var createInvoiceHandler: ((OrderBuy, CustomerInfo) async throws -> Invoice)?

    func createInvoice(from order: OrderBuy, customerInfo: CustomerInfo) async throws -> Invoice {
        if let handler = createInvoiceHandler {
            return try await handler(order, customerInfo)
        } else {
            // Default: create simple invoice
            return Invoice(...)
        }
    }
}

// Test
func testCreateInvoice() async {
    let expectedInvoice = Invoice.sampleInvoice()
    let expectation = XCTestExpectation(description: "Create invoice")

    mockService.createInvoiceHandler = { _, _ in
        expectation.fulfill()
        return expectedInvoice
    }

    viewModel.createInvoice(...)
    await fulfillment(of: [expectation], timeout: 1.0)

    XCTAssertEqual(viewModel.invoices.count, 1)
}
```

#### ❌ FORBIDDEN: Multi-Property Mock Pattern

```swift
// ❌ FORBIDDEN: Multiple configuration properties
class MockInvoiceService: InvoiceServiceProtocol {
    var shouldThrowError = false
    var mockError: AppError = ...
    var mockCreateInvoiceResult: Invoice?
    var mockUpdateResult: Invoice?
    // ... many more properties
}

// ❌ FORBIDDEN: Guard statements throwing errors
func createInvoice(...) async throws -> Invoice {
    guard let result = mockCreateInvoiceResult else {
        throw AppError.serviceError("No mock result provided")
    }
    return result
}
```

### Error Testing Pattern

**MANDATORY**: Errors should be defined directly in closures, not via `shouldThrowError` flags.

#### ✅ CORRECT: Error in Closure

```swift
func testErrorHandling() async {
    let expectedError = AppError.serviceError("Test error")
    let expectation = XCTestExpectation(description: "Error handling")

    mockService.methodHandler = {
        expectation.fulfill()
        throw expectedError
    }

    viewModel.method()
    await fulfillment(of: [expectation], timeout: 1.0)

    XCTAssertTrue(viewModel.showError)
}
```

#### ❌ FORBIDDEN: shouldThrowError Pattern

```swift
// ❌ FORBIDDEN
mockService.shouldThrowError = true
mockService.errorToThrow = AppError.serviceError("Test")
```

### Async Testing Pattern

**MANDATORY**: Use `XCTestExpectation` for async operations, never `Task.sleep`.

#### ✅ CORRECT: XCTestExpectation

```swift
func testAsyncMethod() async {
    let expectation = XCTestExpectation(description: "Method name")

    mockService.methodHandler = {
        expectation.fulfill()
        return result
    }

    viewModel.method()
    await fulfillment(of: [expectation], timeout: 1.0)

    XCTAssertEqual(...)
}
```

#### ❌ FORBIDDEN: Task.sleep

```swift
// ❌ FORBIDDEN: Fragile sleep-based waiting
viewModel.method()
try? await Task.sleep(nanoseconds: 100_000_000)
```

## Repository Testing Pattern

### ✅ REQUIRED: In-Memory UserDefaults for Repositories

**MANDATORY**: All UserDefaults-backed repositories must accept `UserDefaults` as a parameter for testability.

#### Repository Pattern

```swift
// Repository must accept UserDefaults parameter
final class SavedFiltersRepository: ObservableObject {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        // ...
    }
}
```

#### Test Pattern

```swift
func testRepository() {
    // Use in-memory UserDefaults (unique suite per test)
    let userDefaults = UserDefaults(suiteName: UUID().uuidString)!
    let repository = SavedFiltersRepository(userDefaults: userDefaults)

    // Test with isolated, in-memory storage
    repository.addFilter(filter)
    XCTAssertEqual(repository.savedFilters.count, 1)

    // Test persistence (simulates app restart)
    let newRepository = SavedFiltersRepository(userDefaults: userDefaults)
    XCTAssertEqual(newRepository.savedFilters.count, 1)
}
```

**Benefits:**
- ✅ Fast (in-memory, no disk I/O)
- ✅ Isolated (each test gets fresh storage)
- ✅ Realistic (uses actual UserDefaults API)
- ✅ No cleanup needed

## Test Coverage Requirements

### Minimum Coverage
- **Critical paths**: 80%+ code coverage
- **ViewModels**: All public methods and state changes
- **Services**: All business logic paths
- **Repositories**: All CRUD operations

### Required Test Types

1. **Unit Tests** (Fast, Isolated)
   - ViewModel logic
   - Business logic validation
   - Error handling scenarios
   - Use simplified mocks (closure-based)

2. **Repository Tests** (Fast, Realistic)
   - Data persistence logic
   - Query logic
   - Filter/search functionality
   - Use in-memory UserDefaults

3. **Integration Tests** (Slower, High Confidence)
   - End-to-end flows
   - API contract validation
   - Schema migration testing
   - Use containerized environment (future)

## Test Naming Conventions

### Test Method Names
- Use descriptive names: `testMethodName_Scenario_ExpectedResult`
- Examples:
  - `testCreateInvoice_WithValidOrder_ReturnsInvoice`
  - `testSignIn_WithInvalidCredentials_ShowsError`
  - `testAddFilter_PersistsToUserDefaults`

### Test Organization
```swift
final class ViewModelTests: XCTestCase {
    // MARK: - Setup
    override func setUp() { ... }
    override func tearDown() { ... }

    // MARK: - Success Cases
    func testMethodSuccess() { ... }

    // MARK: - Error Cases
    func testMethodError() { ... }

    // MARK: - Edge Cases
    func testMethodEdgeCase() { ... }
}
```

## Mock Reset Pattern

**MANDATORY**: All mocks must implement `reset()` method that clears handlers.

```swift
func reset() {
    // Clear state
    data.removeAll()
    isLoading = false

    // Reset all handlers
    methodHandler = nil
    errorHandler = nil
}
```

## Documentation References

### Migration Guide
- **Location**: `FIN1Tests/TestMigrationGuide.md`
- **Purpose**: Step-by-step guide for migrating existing tests to new patterns

### Strategy Guide
- **Location**: `FIN1Tests/TestEnvironmentStrategy.md`
- **Purpose**: Comprehensive guide on when to use mocks vs in-memory vs containerized tests

### Examples
- **Location**: `FIN1Tests/ContainerizedTestExample.md`
- **Purpose**: Examples for future containerized integration tests

## Guardrails (Fail PRs if Violated)

### Mocking Violations
- ❌ **FORBIDDEN**: `shouldThrowError` property in mocks
- ❌ **FORBIDDEN**: `mock*Result` properties in mocks
- ❌ **FORBIDDEN**: Guard statements throwing errors in mocks
- ❌ **FORBIDDEN**: `Task.sleep` in tests (use `XCTestExpectation`)
- ✅ **REQUIRED**: Closure-based handlers in all mocks
- ✅ **REQUIRED**: Sensible defaults (no errors thrown if handler not set)
- ✅ **REQUIRED**: `XCTestExpectation` for all async operations

### Repository Testing Violations
- ❌ **FORBIDDEN**: Hardcoded `UserDefaults.standard` in repositories
- ✅ **REQUIRED**: `UserDefaults` parameter with `.standard` default
- ✅ **REQUIRED**: In-memory `UserDefaults` in tests

### Test Structure Violations
- ❌ **FORBIDDEN**: Tests outside `FIN1Tests/` or `FIN1UITests/`
- ❌ **FORBIDDEN**: Nested test directories
- ✅ **REQUIRED**: One test file per ViewModel/Service/Repository

## Quick Reference

### Creating a New Mock

1. Create closure handlers for each method:
   ```swift
   var methodHandler: ((Params) async throws -> Return)?
   ```

2. Implement method with handler check:
   ```swift
   func method(_ params: Params) async throws -> Return {
       if let handler = methodHandler {
           return try await handler(params)
       } else {
           // Sensible default
           return defaultValue
       }
   }
   ```

3. Reset handlers in `reset()`:
   ```swift
   func reset() {
       methodHandler = nil
   }
   ```

### Writing a Test

1. Set up mock with handler:
   ```swift
   let expectation = XCTestExpectation(description: "...")
   mockService.methodHandler = {
       expectation.fulfill()
       return result
   }
   ```

2. Call method and wait:
   ```swift
   viewModel.method()
   await fulfillment(of: [expectation], timeout: 1.0)
   ```

3. Assert:
   ```swift
   XCTAssertEqual(...)
   ```

### Testing Repositories

1. Create in-memory UserDefaults:
   ```swift
   let userDefaults = UserDefaults(suiteName: UUID().uuidString)!
   ```

2. Create repository:
   ```swift
   let repository = Repository(userDefaults: userDefaults)
   ```

3. Test operations:
   ```swift
   repository.add(data)
   XCTAssertEqual(repository.items.count, 1)
   ```

## Examples in Codebase

### Simplified Mocks (Reference)
- `FIN1Tests/MockInvoiceService.swift` - Closure-based pattern
- `FIN1Tests/MockUserService.swift` - Closure-based pattern
- `FIN1Tests/MockDocumentService.swift` - Closure-based pattern
- `FIN1Tests/MockInvestmentService.swift` - Closure-based pattern
- `FIN1Tests/MockTraderService.swift` - Closure-based pattern

### Updated Tests (Reference)
- `FIN1Tests/InvoiceViewModelTests.swift` - Uses simplified mocks
- `FIN1Tests/IntegrationTests.swift` - Uses simplified mocks
- `FIN1Tests/DashboardViewModelTests.swift` - Uses simplified mocks
- `FIN1Tests/AuthenticationViewModelTests.swift` - Uses simplified mocks

### Repository Tests (Reference)
- `FIN1Tests/RepositoryTests.swift` - In-memory UserDefaults pattern

## Test Organization & Best Practices

### ✅ REQUIRED: Use Helper Methods for Common Logic

**MANDATORY**: Outsource common test logic and reusable setup routines to helper methods.

#### Central Helpers
- Use `TestHelpers` class for shared utilities
- Location: `FIN1Tests/TestHelpers.swift`

#### Extension Helpers
- Use test file extensions for test-specific helpers
- Example: `InvoiceTestHelpers.swift` for invoice-specific helpers

#### Helper Organization
```swift
// ✅ CORRECT: Central helper for common operations
let userDefaults = TestHelpers.createInMemoryUserDefaults()
let expectation = TestHelpers.createExpectation(description: "Operation")

// ✅ CORRECT: Extension helper for test-specific data
extension InvoiceViewModelTests {
    func createSampleOrderBuy() -> OrderBuy { ... }
}
```

#### ❌ FORBIDDEN: Duplicated Setup Code

```swift
// ❌ FORBIDDEN: Repeated setup in every test
func test1() {
    let userDefaults = UserDefaults(suiteName: UUID().uuidString)!
    // ... setup code
}

func test2() {
    let userDefaults = UserDefaults(suiteName: UUID().uuidString)!
    // ... same setup code
}
```

### ✅ REQUIRED: Keep Tests Small and Focused

**MANDATORY**: Each test should validate only one aspect of functionality.

#### ✅ CORRECT: Focused Test

```swift
func testTotalInvoices_WithTwoInvoices_ReturnsTwo() {
    // Given
    viewModel.invoices = [invoice1, invoice2]

    // Then
    XCTAssertEqual(viewModel.totalInvoices, 2)
}
```

#### ❌ FORBIDDEN: Multiple Aspects in One Test

```swift
// ❌ FORBIDDEN: Testing multiple aspects
func testInvoiceOperations() {
    // Tests creation, update, deletion, and validation all in one
    XCTAssertEqual(...) // creation
    XCTAssertEqual(...) // update
    XCTAssertEqual(...) // deletion
    XCTAssertTrue(...)  // validation
}
```

#### ✅ CORRECT: Separate Tests for Each Aspect

```swift
func testCreateInvoice_WithValidOrder_ReturnsInvoice() { ... }
func testUpdateInvoice_WithValidData_UpdatesInvoice() { ... }
func testDeleteInvoice_WithValidId_RemovesInvoice() { ... }
func testValidateInvoice_WithValidData_ReturnsTrue() { ... }
```

### ✅ RECOMMENDED: Peer Review of Tests

**RECOMMENDED**: Conduct peer reviews of tests to critically examine dependencies and benefits.

#### Review Checklist
- [ ] Are tests focused (one aspect per test)?
- [ ] Are helpers used for common logic?
- [ ] Are mocks using closure-based pattern?
- [ ] Are async operations using `XCTestExpectation`?
- [ ] Are repository tests using in-memory UserDefaults?
- [ ] Do tests have clear, descriptive names?
- [ ] Are test dependencies minimal and clear?
- [ ] Do tests provide value (catch real bugs)?

#### Review Process
1. **Before PR**: Review tests alongside code changes
2. **Focus Areas**:
   - Test clarity and maintainability
   - Proper use of helpers
   - Focused test scope
   - Appropriate mocking strategy
3. **Questions to Ask**:
   - Is this test testing the right thing?
   - Could this logic be extracted to a helper?
   - Is this test too complex?
   - Are dependencies clear?

## Migration

If you encounter tests using the old pattern:
1. See `FIN1Tests/TestMigrationGuide.md` for step-by-step instructions
2. Replace `shouldThrowError` with closure handlers
3. Replace `Task.sleep` with `XCTestExpectation`
4. Update repository tests to use in-memory UserDefaults
5. Extract common logic to helper methods
6. Split multi-aspect tests into focused tests

