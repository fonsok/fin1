# Test Migration Guide - Simplified Mocking Pattern

## Overview

This guide helps you migrate existing tests from the old complex mocking pattern to the new simplified closure-based approach.

## Migration Pattern

### Before (Old Pattern)

```swift
// Setup: Multiple properties
mockService.shouldThrowError = false
mockService.errorToThrow = AppError.serviceError("Test")
mockService.mockResult = expectedResult

// Test
viewModel.someMethod()
try? await Task.sleep(nanoseconds: 100_000_000)

// Assertions
XCTAssertEqual(...)
```

### After (New Pattern)

```swift
// Setup: Single closure
let expectation = XCTestExpectation(description: "Some method")
mockService.someMethodHandler = {
    expectation.fulfill()
    return expectedResult
}

// Test
viewModel.someMethod()
await fulfillment(of: [expectation], timeout: 1.0)

// Assertions
XCTAssertEqual(...)
```

## Step-by-Step Migration

### Step 1: Identify Old Pattern Usage

Look for these patterns in your tests:
- `mockService.shouldThrowError = true/false`
- `mockService.errorToThrow = ...`
- `mockService.mock*Result = ...`
- `try? await Task.sleep(...)`

### Step 2: Replace with Closures

**For Success Cases:**
```swift
// Before
mockService.mockResult = expectedResult

// After
mockService.methodHandler = { _ in expectedResult }
```

**For Error Cases:**
```swift
// Before
mockService.shouldThrowError = true
mockService.errorToThrow = AppError.serviceError("Test")

// After
mockService.methodHandler = { throw AppError.serviceError("Test") }
```

### Step 3: Replace Task.sleep with XCTestExpectation

```swift
// Before
try? await Task.sleep(nanoseconds: 100_000_000)

// After
let expectation = XCTestExpectation(description: "Method name")
mockService.methodHandler = {
    expectation.fulfill()
    // ... handler logic
}
await fulfillment(of: [expectation], timeout: 1.0)
```

## Examples by Mock Type

### MockInvoiceService

**Before:**
```swift
mockInvoiceService.mockCreateInvoiceResult = expectedInvoice
mockInvoiceService.shouldThrowError = false
```

**After:**
```swift
mockInvoiceService.createInvoiceFromOrderHandler = { _, _ in expectedInvoice }
```

### MockUserService

**Before:**
```swift
mockUserService.shouldThrowError = true
mockUserService.errorToThrow = AppError.authenticationError(.invalidCredentials)
```

**After:**
```swift
mockUserService.signInHandler = { _, _ in
    throw AppError.authenticationError(.invalidCredentials)
}
```

### MockInvestmentService

**Before:**
```swift
mockInvestmentService.shouldThrowError = false
mockInvestmentService.createInvestmentDelay = 0.1
```

**After:**
```swift
mockInvestmentService.createInvestmentHandler = { investor, trader, amount, pots, spec in
    // Custom behavior if needed
}
// Or omit handler to use default behavior
```

### MockTraderService

**Before:**
```swift
mockTraderService.shouldThrowError = true
mockTraderService.errorToThrow = AppError.serviceError("Test")
```

**After:**
```swift
mockTraderService.createNewTradeHandler = { buyOrder in
    throw AppError.serviceError("Test")
}
```

## Common Patterns

### Pattern 1: Simple Success Case

**Before:**
```swift
mockService.mockResult = expectedValue
viewModel.method()
try? await Task.sleep(nanoseconds: 100_000_000)
XCTAssertEqual(viewModel.result, expectedValue)
```

**After:**
```swift
let expectation = XCTestExpectation(description: "Method")
mockService.methodHandler = {
    expectation.fulfill()
    return expectedValue
}
viewModel.method()
await fulfillment(of: [expectation], timeout: 1.0)
XCTAssertEqual(viewModel.result, expectedValue)
```

### Pattern 2: Error Case

**Before:**
```swift
mockService.shouldThrowError = true
mockService.errorToThrow = AppError.serviceError("Test")
viewModel.method()
try? await Task.sleep(nanoseconds: 100_000_000)
XCTAssertTrue(viewModel.showError)
```

**After:**
```swift
let expectation = XCTestExpectation(description: "Method error")
mockService.methodHandler = {
    expectation.fulfill()
    throw AppError.serviceError("Test")
}
viewModel.method()
await fulfillment(of: [expectation], timeout: 1.0)
XCTAssertTrue(viewModel.showError)
```

### Pattern 3: No Handler Needed (Uses Default)

**Before:**
```swift
mockService.shouldThrowError = false
// No mock result set - would throw error in old pattern
viewModel.method()
try? await Task.sleep(nanoseconds: 100_000_000)
```

**After:**
```swift
// No handler needed - uses sensible default
let expectation = XCTestExpectation(description: "Method")
// Set expectation in default behavior or use default
viewModel.method()
await fulfillment(of: [expectation], timeout: 1.0)
```

## Benefits After Migration

1. **Less Boilerplate** - 1-2 lines instead of 3-5
2. **Clearer Intent** - Closure shows exactly what's being tested
3. **Better Async** - Proper XCTestExpectation instead of sleep
4. **No Guard Errors** - Sensible defaults, no errors thrown
5. **More Flexible** - Closures can implement any behavior

## Checklist

When migrating a test:

- [ ] Remove `shouldThrowError` assignments
- [ ] Remove `errorToThrow` assignments
- [ ] Remove `mock*Result` assignments
- [ ] Replace with appropriate handler closure
- [ ] Replace `Task.sleep` with `XCTestExpectation`
- [ ] Use `await fulfillment(of: [expectation], timeout: 1.0)`
- [ ] Verify test still passes
- [ ] Verify test is clearer and easier to understand

## Files Already Migrated

✅ `InvoiceViewModelTests.swift` - Complete
✅ `IntegrationTests.swift` - Complete
✅ `DashboardViewModelTests.swift` - Complete
✅ `AuthenticationViewModelTests.swift` - Complete

## Remaining Files (Optional)

These files may still use the old pattern:
- Other ViewModel tests
- Service tests
- Integration tests

Migrate them as needed using this guide.


