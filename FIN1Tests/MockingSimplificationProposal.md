# Mocking Simplification Proposal

## Current Problems

1. **Too many configuration properties** - Each mock has 5-10+ properties to configure
2. **Repetitive error handling** - Every method checks `shouldThrowError`
3. **Guard statements** - Methods throw if mock results aren't provided
4. **Stateful mocks** - @Published properties can cause test interference
5. **Fragile async handling** - Using `Task.sleep` instead of expectations

## Proposed Simplification

### 1. Use Result Builders or Closures for Behavior

Instead of multiple properties, use closures that return results:

```swift
class MockInvoiceService: InvoiceServiceProtocol {
    // Simple state
    var invoices: [Invoice] = []

    // Behavior closures (default to success)
    var loadInvoicesHandler: ((String) async throws -> [Invoice])?
    var createInvoiceHandler: ((Trade, CustomerInfo) async throws -> Invoice)?
    var updateInvoiceHandler: ((String, InvoiceStatus) async throws -> Invoice)?

    func loadInvoices(for userId: String) async throws {
        if let handler = loadInvoicesHandler {
            invoices = try await handler(userId)
        } else {
            // Default: return existing invoices
        }
    }

    func createInvoice(from trade: Trade, customerInfo: CustomerInfo) async throws -> Invoice {
        if let handler = createInvoiceHandler {
            let invoice = try await handler(trade, customerInfo)
            invoices.append(invoice)
            return invoice
        } else {
            // Default: create simple invoice
            let invoice = Invoice(/* from trade */)
            invoices.append(invoice)
            return invoice
        }
    }
}
```

### 2. Simplified Test Usage

```swift
func testCreateInvoice() async {
    // Given
    let expectedInvoice = Invoice.sampleInvoice()
    mockInvoiceService.createInvoiceHandler = { _, _ in
        return expectedInvoice
    }

    // When
    let result = try await viewModel.createInvoice(from: trade, customerInfo: info)

    // Then
    XCTAssertEqual(result.id, expectedInvoice.id)
}

func testCreateInvoiceError() async {
    // Given
    mockInvoiceService.createInvoiceHandler = { _, _ in
        throw AppError.serviceError("Test error")
    }

    // When/Then
    await XCTAssertThrowsError(try await viewModel.createInvoice(...))
}
```

### 3. Remove @Published from Mocks

Mocks don't need to be ObservableObject - they're just test doubles:

```swift
// ❌ Current
class MockInvoiceService: InvoiceServiceProtocol {
    @Published var invoices: [Invoice] = []
}

// ✅ Simplified
class MockInvoiceService: InvoiceServiceProtocol {
    var invoices: [Invoice] = []
}
```

### 4. Use XCTestExpectation for Async

```swift
func testLoadInvoices() async {
    let expectation = XCTestExpectation(description: "Load invoices")

    mockInvoiceService.loadInvoicesHandler = { _ in
        expectation.fulfill()
        return [Invoice.sampleInvoice()]
    }

    viewModel.loadInvoices(for: "test-user")
    await fulfillment(of: [expectation], timeout: 1.0)

    XCTAssertEqual(viewModel.invoices.count, 1)
}
```

## Benefits

1. **Less boilerplate** - No need to set multiple properties
2. **More flexible** - Closures can implement any behavior
3. **Clearer intent** - Test shows exactly what behavior is being tested
4. **Less state** - No @Published properties to manage
5. **Better async** - Proper expectations instead of sleep

## Migration Strategy

1. Start with one mock (e.g., `MockInvoiceService`)
2. Convert to closure-based approach
3. Update all tests using that mock
4. Repeat for other mocks
5. Remove unused properties and reset methods


