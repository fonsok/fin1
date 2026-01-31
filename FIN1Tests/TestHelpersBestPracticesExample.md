# Test Helpers Best Practices - Examples

## Overview

This document demonstrates the improved test helper patterns and shows before/after examples of tests updated to use the new helper methods.

## Key Improvements

### 1. ✅ Proper Async Testing with XCTestExpectation

**Before (Deprecated):**
```swift
func testSignInSuccess() async {
    viewModel.signIn(email: "test@example.com", password: "password123")
    await TestHelpers.waitForAsync() // ❌ Uses Task.sleep - fragile
    XCTAssertTrue(viewModel.isAuthenticated)
}
```

**After (Improved):**
```swift
func testSignInSuccess() async {
    let expectation = TestHelpers.createExpectation(description: "Sign in success")
    mockUserService.signInHandler = { _, _ in
        expectation.fulfill()
    }

    viewModel.signIn(email: "test@example.com", password: "password123")
    await TestHelpers.waitForExpectation(expectation) // ✅ Proper async handling

    XCTAssertTrue(viewModel.isAuthenticated)
}
```

### 2. ✅ Using Helper Methods for Common Operations

**Before:**
```swift
func testUserDisplayName() async {
    try? await mockUserService.signIn(email: "test@example.com", password: "password123")
    await TestHelpers.waitForAsync() // ❌ Deprecated
    XCTAssertEqual(viewModel.userDisplayName, "Test User")
}
```

**After:**
```swift
func testUserDisplayName() async {
    let expectation = TestHelpers.createExpectation(description: "Sign in for display name")
    mockUserService.signInHandler = { _, _ in
        expectation.fulfill()
    }
    try? await mockUserService.signIn(email: "test@example.com", password: "password123")
    await TestHelpers.waitForExpectation(expectation) // ✅ Uses helper

    XCTAssertEqual(viewModel.userDisplayName, "Test User")
}
```

### 3. ✅ In-Memory UserDefaults for Repository Tests

**Before:**
```swift
func testRepository() {
    let repository = SavedFiltersRepository() // ❌ Uses .standard
    repository.addFilter(filter)
    XCTAssertEqual(repository.savedFilters.count, 1)
}
```

**After:**
```swift
func testRepository() {
    let userDefaults = TestHelpers.createInMemoryUserDefaults() // ✅ Isolated
    let repository = SavedFiltersRepository(userDefaults: userDefaults)
    repository.addFilter(filter)
    XCTAssertEqual(repository.savedFilters.count, 1)
}
```

## Available Helper Methods

### Async Test Helpers

```swift
// Create an expectation
let expectation = TestHelpers.createExpectation(description: "Operation")

// Wait for expectation
await TestHelpers.waitForExpectation(expectation)

// Convenience: Create and wait in one call
await TestHelpers.waitForAsync(
    description: "Operation",
    operation: { expectation in
        // Your async operation that fulfills expectation
        someAsyncOperation { expectation.fulfill() }
    }
)
```

### Repository Test Helpers

```swift
// Create isolated in-memory UserDefaults
let userDefaults = TestHelpers.createInMemoryUserDefaults()
let repository = Repository(userDefaults: userDefaults)
```

### User Creation Helpers

```swift
// Create test user
await TestHelpers.createTestUser(
    email: "test@example.com",
    role: .investor,
    mockUserService: mockUserService
)

// Create investor user
await TestHelpers.createInvestorUser(mockUserService: mockUserService)

// Create trader user
await TestHelpers.createTraderUser(mockUserService: mockUserService)
```

### Mock Configuration Helpers

```swift
// Configure mock to return value
TestHelpers.configureMockHandler(
    handler: &mockService.methodHandler,
    value: expectedResult,
    expectation: expectation
)

// Configure mock to throw error
TestHelpers.configureMockErrorHandler(
    handler: &mockService.errorHandler,
    error: AppError.serviceError("Test"),
    expectation: expectation
)
```

## Test Organization Pattern

### ✅ CORRECT: Focused Test with Helpers

```swift
func testSignInSuccess() async {
    // Given - Use helpers for setup
    let expectation = TestHelpers.createExpectation(description: "Sign in")
    mockUserService.signInHandler = { _, _ in
        expectation.fulfill()
    }

    // When
    viewModel.signIn(email: "test@example.com", password: "password123")
    await TestHelpers.waitForExpectation(expectation)

    // Then - One focused assertion
    XCTAssertTrue(viewModel.isAuthenticated)
}
```

### ❌ FORBIDDEN: Multiple Aspects in One Test

```swift
func testSignInOperations() async {
    // ❌ Testing multiple aspects
    viewModel.signIn(...)
    XCTAssertTrue(viewModel.isAuthenticated) // aspect 1
    XCTAssertNotNil(viewModel.currentUser)    // aspect 2
    XCTAssertEqual(viewModel.email, "...")   // aspect 3
}
```

### ✅ CORRECT: Separate Tests for Each Aspect

```swift
func testSignIn_WithValidCredentials_SetsAuthenticated() async { ... }
func testSignIn_WithValidCredentials_SetsCurrentUser() async { ... }
func testSignIn_WithValidCredentials_UpdatesEmail() async { ... }
```

## Migration Checklist

When updating tests:

- [ ] Replace `TestHelpers.waitForAsync()` with `XCTestExpectation`
- [ ] Use `TestHelpers.createExpectation()` for creating expectations
- [ ] Use `TestHelpers.waitForExpectation()` for waiting
- [ ] Use `TestHelpers.createInMemoryUserDefaults()` for repository tests
- [ ] Extract common setup to helper methods
- [ ] Split multi-aspect tests into focused tests
- [ ] Use closure-based mock handlers

## Files Updated

✅ `AuthenticationViewModelTests.swift` - All tests updated
✅ `DashboardViewModelTests.swift` - All tests updated
✅ `TestHelpers.swift` - Enhanced with new helpers

## Benefits Achieved

1. **Reliable Async Testing** - No more fragile `Task.sleep`
2. **Clearer Tests** - Expectations show what's being tested
3. **Better Isolation** - In-memory UserDefaults for repositories
4. **Reusable Helpers** - Common patterns extracted
5. **Focused Tests** - One aspect per test


