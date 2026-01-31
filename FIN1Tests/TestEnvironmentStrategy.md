# Test Environment Strategy: Containerized vs In-Memory vs Mocking

## Executive Summary

**For your architecture (Parse Server + MongoDB + SwiftUI):**

✅ **Recommended Hybrid Approach:**
- **Integration Tests**: Containerized test environment (Docker Compose)
- **Unit Tests**: Simplified mocking (closure-based) + in-memory where applicable
- **Repository Tests**: In-memory SQLite for UserDefaults-backed repositories

## Architecture Context

Your stack:
- **Backend**: Parse Server (MongoDB), PostgreSQL, Redis
- **Frontend**: SwiftUI iOS app
- **Local Storage**: UserDefaults for preferences/filters
- **Network**: REST API via Parse Server

## Option 1: Containerized Test Environment

### ✅ Advantages

1. **Realistic Testing**
   - Tests against actual Parse Server, MongoDB, PostgreSQL
   - Catches integration issues that mocks miss
   - Validates actual API contracts and data serialization
   - Tests real database queries, indexes, constraints

2. **Reduced Mock Complexity**
   - No need to mock Parse Server SDK behavior
   - No need to mock MongoDB query results
   - Tests work with real Parse objects and schemas
   - Validates actual network serialization/deserialization

3. **Better Confidence**
   - Tests closer to production environment
   - Catches schema migration issues
   - Validates authentication/authorization flows
   - Tests actual error handling from real services

4. **Easier Maintenance**
   - When Parse Server API changes, tests fail (good!)
   - No need to update mocks when backend changes
   - Tests document actual API behavior

### ❌ Disadvantages

1. **Slower Tests**
   - Container startup time (5-10 seconds)
   - Network latency (even localhost)
   - Database operations slower than in-memory
   - Can't run thousands of tests quickly

2. **Setup Complexity**
   - Need Docker Compose for tests
   - CI/CD must support Docker
   - Test data cleanup between tests
   - Port conflicts if containers already running

3. **iOS-Specific Challenges**
   - iOS Simulator can't easily connect to Docker containers
   - Need network configuration
   - Parse Server SDK may need special test configuration
   - Harder to debug (network + container logs)

4. **Resource Usage**
   - Requires Docker running
   - Memory for containers (MongoDB, Parse Server, etc.)
   - Disk space for container images

### Implementation Example

```swift
// Test setup with containerized backend
final class IntegrationTests: XCTestCase {
    static var parseServerURL: String {
        // Point to test Parse Server container
        return "http://localhost:1337/parse"
    }

    override func setUp() {
        super.setUp()
        // Ensure test containers are running
        // docker-compose -f docker-compose.test.yml up -d
    }

    override func tearDown() {
        // Clean test data
        // Clear MongoDB test database
        super.tearDown()
    }

    func testCreateInvoice() async throws {
        // Use real Parse Server
        let service = InvoiceService(parseServerURL: Self.parseServerURL)
        let invoice = try await service.createInvoice(...)

        // Verify in real database
        let fetched = try await service.getInvoice(by: invoice.id)
        XCTAssertNotNil(fetched)
    }
}
```

## Option 2: In-Memory Databases

### ✅ Advantages

1. **Fast Tests**
   - No network overhead
   - No container startup
   - In-memory operations are instant
   - Can run thousands of tests quickly

2. **Simple Setup**
   - No Docker required
   - Works in CI/CD easily
   - No port conflicts
   - Easy to reset between tests

3. **Good for Repositories**
   - Perfect for UserDefaults-backed repositories
   - Can use in-memory SQLite for complex queries
   - Tests actual query logic without network

4. **Isolated Tests**
   - Each test gets fresh database
   - No test interference
   - Easy to parallelize

### ❌ Disadvantages

1. **Not Realistic**
   - Parse Server SDK behavior may differ
   - No network serialization testing
   - MongoDB-specific features not available
   - May miss integration issues

2. **Limited for Parse Server**
   - Parse Server SDK expects real Parse Server
   - Can't easily use in-memory MongoDB with Parse
   - Parse objects have server-side behavior
   - Cloud functions won't run

3. **Still Need Some Mocking**
   - Network layer still needs mocking
   - Parse Server SDK still needs configuration
   - Not a complete replacement

### Implementation Example

```swift
// In-memory UserDefaults for repository tests
final class SavedFiltersRepositoryTests: XCTestCase {
    var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Use in-memory UserDefaults
        userDefaults = UserDefaults(suiteName: UUID().uuidString)
    }

    func testSaveFilter() {
        let repo = SavedSecuritiesFiltersRepository(userDefaults: userDefaults)
        let filter = SecuritiesFilterCombination(...)

        repo.addFilter(filter)

        XCTAssertEqual(repo.savedFilters.count, 1)
    }
}

// In-memory SQLite for complex queries
final class ComplexQueryTests: XCTestCase {
    var db: SQLiteDatabase!

    override func setUp() {
        super.setUp()
        // In-memory SQLite
        db = SQLiteDatabase(path: ":memory:")
    }

    func testComplexQuery() {
        // Test actual SQL queries
        let results = db.execute("SELECT ...")
        XCTAssertEqual(results.count, 5)
    }
}
```

## Option 3: Simplified Mocking (Current Problem)

### ✅ Advantages

1. **Fast Tests**
   - No external dependencies
   - Instant execution
   - Easy to parallelize

2. **Full Control**
   - Test exact scenarios
   - Easy to test error cases
   - No flakiness from network

### ❌ Disadvantages (Your Current Issue)

1. **Too Complex**
   - 5-10+ properties per mock
   - Repetitive boilerplate
   - Hard to maintain
   - Tests are verbose

2. **Diverges from Reality**
   - Mocks may not match real behavior
   - Parse Server SDK quirks not tested
   - Network serialization not validated

## Recommended Hybrid Strategy

### Layer 1: Unit Tests (Fast, Isolated)
**Use**: Simplified mocking (closure-based) + in-memory where applicable

```swift
// Simplified mock with closures
class MockInvoiceService: InvoiceServiceProtocol {
    var createInvoiceHandler: ((OrderBuy, CustomerInfo) async throws -> Invoice)?

    func createInvoice(from order: OrderBuy, customerInfo: CustomerInfo) async throws -> Invoice {
        if let handler = createInvoiceHandler {
            return try await handler(order, customerInfo)
        }
        // Default behavior
        return Invoice(...)
    }
}

// Test
func testCreateInvoice() async {
    let expected = Invoice.sampleInvoice()
    mockService.createInvoiceHandler = { _, _ in expected }

    let result = try await viewModel.createInvoice(...)
    XCTAssertEqual(result.id, expected.id)
}
```

**When to use:**
- ViewModel logic tests
- Business logic validation
- Error handling scenarios
- Fast feedback during development

### Layer 2: Repository Tests (In-Memory)
**Use**: In-memory UserDefaults, in-memory SQLite

```swift
// Test UserDefaults-backed repositories
func testFilterPersistence() {
    let userDefaults = UserDefaults(suiteName: UUID().uuidString)
    let repo = FilterPersistenceRepository(userDefaults: userDefaults)

    repo.setAppliedFilterID("test-id")
    XCTAssertEqual(repo.getAppliedFilterID(), "test-id")
}
```

**When to use:**
- Data persistence logic
- Query logic
- Filter/search functionality
- Local storage operations

### Layer 3: Integration Tests (Containerized)
**Use**: Docker Compose test environment

```swift
// Test against real Parse Server
final class InvoiceIntegrationTests: XCTestCase {
    var testParseServer: ParseServerClient!

    override func setUp() {
        // Start test containers
        // docker-compose -f docker-compose.test.yml up -d
        testParseServer = ParseServerClient(url: "http://localhost:1337/parse")
    }

    func testCreateInvoiceIntegration() async throws {
        let service = InvoiceService(parseServer: testParseServer)
        let invoice = try await service.createInvoice(...)

        // Verify in real database
        let fetched = try await service.getInvoice(by: invoice.id)
        XCTAssertNotNil(fetched)
    }
}
```

**When to use:**
- End-to-end flows
- API contract validation
- Schema migration testing
- Authentication/authorization
- Before releases

## Implementation Plan

### Phase 1: Simplify Current Mocks (Immediate)
1. Refactor mocks to use closures instead of multiple properties
2. Remove `shouldThrowError` pattern
3. Add sensible defaults
4. Update tests to use simplified approach

**Benefit**: Immediate reduction in complexity, easier to maintain

### Phase 2: Add In-Memory Repository Tests (Short-term)
1. Create in-memory UserDefaults for repository tests
2. Add in-memory SQLite for complex queries (if needed)
3. Test actual persistence logic without network

**Benefit**: Fast, realistic tests for data layer

### Phase 3: Add Containerized Integration Tests (Medium-term)
1. Create `docker-compose.test.yml` for test environment
2. Add test data seeding scripts
3. Create integration test suite
4. Run in CI/CD

**Benefit**: High confidence in production behavior

## Specific Recommendations for Your Codebase

### 1. UserDefaults Repositories
**Use in-memory UserDefaults:**
```swift
let testDefaults = UserDefaults(suiteName: UUID().uuidString)
let repo = SavedSecuritiesFiltersRepository(userDefaults: testDefaults)
```

### 2. Parse Server Services
**Hybrid approach:**
- Unit tests: Simplified mocks (closure-based)
- Integration tests: Containerized Parse Server

### 3. Network Services
**Use URLProtocol mocking for network:**
```swift
class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else { return }
        let (response, data) = try! handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
```

### 4. Complex Business Logic
**Use in-memory SQLite for query testing:**
```swift
// If you need complex queries
let db = try SQLiteDatabase(path: ":memory:")
// Test actual SQL logic
```

## Cost-Benefit Analysis

| Approach | Setup Time | Test Speed | Realism | Maintenance | Best For |
|----------|-----------|------------|---------|-------------|----------|
| **Complex Mocks** (Current) | Low | Fast | Low | High | ❌ Avoid |
| **Simplified Mocks** | Low | Fast | Medium | Low | Unit tests |
| **In-Memory DB** | Medium | Fast | Medium | Low | Repository tests |
| **Containerized** | High | Slow | High | Medium | Integration tests |

## Conclusion

**For your specific architecture:**

1. **Immediate**: Simplify mocks (closure-based) - reduces complexity 80%
2. **Short-term**: Add in-memory tests for repositories - fast, realistic
3. **Medium-term**: Add containerized integration tests - high confidence

**The key insight**: You don't need to choose one approach. Use the right tool for each layer:
- **Fast unit tests** → Simplified mocks
- **Data layer tests** → In-memory databases
- **Integration tests** → Containerized environment

This gives you:
- ✅ Fast feedback (unit tests)
- ✅ Realistic data testing (in-memory)
- ✅ Production confidence (containerized)
- ✅ Maintainable code (simplified mocks)


