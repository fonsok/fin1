# Containerized Test Environment - Practical Example

## Quick Setup for Parse Server Integration Tests

### 1. Create Test Docker Compose File

```yaml
# docker-compose.test.yml
version: '3.8'

services:
  parse-server-test:
    build:
      context: ./backend/parse-server
      dockerfile: Dockerfile
    container_name: fin1-parse-server-test
    ports:
      - "1338:1337"  # Different port to avoid conflicts
    environment:
      - PARSE_SERVER_APPLICATION_ID=fin1-test
      - PARSE_SERVER_MASTER_KEY=test-master-key
      - PARSE_SERVER_DATABASE_URI=mongodb://mongodb-test:27017/fin1_test
      - PARSE_SERVER_PUBLIC_SERVER_URL=http://localhost:1338/parse
      - NODE_ENV=test
    depends_on:
      - mongodb-test
    networks:
      - test-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:1337/health"]
      interval: 5s
      timeout: 3s
      retries: 3

  mongodb-test:
    image: mongo:7.0
    container_name: fin1-mongodb-test
    ports:
      - "27018:27017"  # Different port
    environment:
      - MONGO_INITDB_DATABASE=fin1_test
    volumes:
      - mongodb_test_data:/data/db
    networks:
      - test-network
    command: mongod --smallfiles  # Faster for tests

volumes:
  mongodb_test_data:

networks:
  test-network:
    driver: bridge
```

### 2. Test Helper for Container Management

```swift
// FIN1Tests/TestContainers.swift
import Foundation
import XCTest

final class TestContainers {
    static let shared = TestContainers()

    private var isRunning = false
    let parseServerURL = "http://localhost:1338/parse"

    func start() throws {
        guard !isRunning else { return }

        // Start containers
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker-compose")
        process.arguments = ["-f", "docker-compose.test.yml", "up", "-d"]
        process.currentDirectoryPath = FileManager.default.currentDirectoryPath
        try process.run()
        process.waitUntilExit()

        // Wait for health check
        try waitForHealthCheck()

        isRunning = true
    }

    func stop() throws {
        guard isRunning else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker-compose")
        process.arguments = ["-f", "docker-compose.test.yml", "down", "-v"]
        process.currentDirectoryPath = FileManager.default.currentDirectoryPath
        try process.run()
        process.waitUntilExit()

        isRunning = false
    }

    func cleanDatabase() async throws {
        // Clean test data between tests
        // Connect to MongoDB and clear collections
    }

    private func waitForHealthCheck() throws {
        var attempts = 0
        while attempts < 30 {
            if let url = URL(string: "\(parseServerURL)/health"),
               let _ = try? Data(contentsOf: url) {
                return
            }
            Thread.sleep(forTimeInterval: 1.0)
            attempts += 1
        }
        throw TestContainerError.timeout
    }
}

enum TestContainerError: Error {
    case timeout
    case notRunning
}
```

### 3. Integration Test Example

```swift
// FIN1Tests/InvoiceServiceIntegrationTests.swift
import XCTest
@testable import FIN1

final class InvoiceServiceIntegrationTests: XCTestCase {
    var containers: TestContainers!
    var invoiceService: InvoiceService!

    override func setUp() async throws {
        try await super.setUp()

        containers = TestContainers.shared
        try containers.start()

        // Initialize service with test Parse Server
        invoiceService = InvoiceService(
            parseServerURL: containers.parseServerURL,
            applicationId: "fin1-test",
            masterKey: "test-master-key"
        )

        // Clean database before each test
        try await containers.cleanDatabase()
    }

    override func tearDown() async throws {
        invoiceService = nil
        try await super.tearDown()
    }

    func testCreateInvoice() async throws {
        // Given
        let trade = createSampleTrade()
        let customerInfo = createSampleCustomerInfo()

        // When
        let invoice = try await invoiceService.createInvoice(
            from: trade,
            customerInfo: customerInfo
        )

        // Then
        XCTAssertNotNil(invoice.id)
        XCTAssertEqual(invoice.tradeId, trade.id)

        // Verify persistence
        let fetched = try await invoiceService.getInvoice(by: invoice.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, invoice.id)
    }

    func testGetInvoicesForTrade() async throws {
        // Given
        let trade = createSampleTrade()
        let invoice1 = try await invoiceService.createInvoice(...)
        let invoice2 = try await invoiceService.createInvoice(...)

        // When
        let invoices = try await invoiceService.getInvoicesForTrade(trade.id)

        // Then
        XCTAssertEqual(invoices.count, 2)
        XCTAssertTrue(invoices.contains { $0.id == invoice1.id })
        XCTAssertTrue(invoices.contains { $0.id == invoice2.id })
    }
}
```

### 4. In-Memory Repository Test Example

```swift
// FIN1Tests/SavedFiltersRepositoryTests.swift
import XCTest
@testable import FIN1

final class SavedFiltersRepositoryTests: XCTestCase {
    var userDefaults: UserDefaults!
    var repository: SavedSecuritiesFiltersRepository!

    override func setUp() {
        super.setUp()
        // Use in-memory UserDefaults (unique suite per test)
        userDefaults = UserDefaults(suiteName: UUID().uuidString)
        repository = SavedSecuritiesFiltersRepository(userDefaults: userDefaults)
    }

    func testAddFilter() {
        // Given
        let filter = SecuritiesFilterCombination(
            id: UUID(),
            name: "Test Filter",
            filters: [],
            isDefault: false
        )

        // When
        repository.addFilter(filter)

        // Then
        XCTAssertEqual(repository.savedFilters.count, 1)
        XCTAssertEqual(repository.savedFilters.first?.id, filter.id)
    }

    func testRemoveFilter() {
        // Given
        let filter = SecuritiesFilterCombination(...)
        repository.addFilter(filter)

        // When
        repository.removeFilter(filter)

        // Then
        XCTAssertEqual(repository.savedFilters.count, 0)
    }

    func testPersistence() {
        // Given
        let filter = SecuritiesFilterCombination(...)
        repository.addFilter(filter)

        // When - Create new repository instance (simulates app restart)
        let newRepository = SavedSecuritiesFiltersRepository(userDefaults: userDefaults)

        // Then - Data should persist
        XCTAssertEqual(newRepository.savedFilters.count, 1)
        XCTAssertEqual(newRepository.savedFilters.first?.id, filter.id)
    }
}
```

## Comparison: Before vs After

### Before (Complex Mocking)
```swift
func testCreateInvoice() async {
    // Setup: 5+ properties
    mockInvoiceService.shouldThrowError = false
    mockInvoiceService.mockError = AppError.unknownError("Test")
    mockInvoiceService.mockCreateInvoiceResult = expectedInvoice
    mockInvoiceService.mockInvoices = []
    mockInvoiceService.mockPDFData = Data()

    // Test
    viewModel.createInvoice(...)
    try? await Task.sleep(nanoseconds: 100_000_000)

    // Assert
    XCTAssertEqual(viewModel.invoices.count, 1)
}
```

### After (Containerized Integration)
```swift
func testCreateInvoice() async throws {
    // Setup: Real service, real database
    let invoice = try await invoiceService.createInvoice(...)

    // Assert: Real persistence
    let fetched = try await invoiceService.getInvoice(by: invoice.id)
    XCTAssertNotNil(fetched)
}
```

### After (In-Memory Repository)
```swift
func testAddFilter() {
    // Setup: In-memory UserDefaults
    let filter = SecuritiesFilterCombination(...)

    // Test: Real persistence logic
    repository.addFilter(filter)

    // Assert: Real query
    XCTAssertEqual(repository.savedFilters.count, 1)
}
```

## When to Use Each Approach

| Test Type | Approach | Example |
|-----------|----------|---------|
| ViewModel logic | Simplified mocks | `InvoiceViewModelTests` |
| Repository persistence | In-memory UserDefaults | `SavedFiltersRepositoryTests` |
| Complex queries | In-memory SQLite | `FilterQueryTests` |
| API integration | Containerized | `InvoiceServiceIntegrationTests` |
| End-to-end flows | Containerized | `InvoiceFlowIntegrationTests` |
| Error scenarios | Simplified mocks | `InvoiceErrorHandlingTests` |

## Performance Comparison

| Approach | Setup Time | Test Duration | Realism |
|----------|-----------|---------------|---------|
| Complex mocks | 0s | 0.1s | Low |
| Simplified mocks | 0s | 0.1s | Medium |
| In-memory DB | 0.1s | 0.2s | High (for data layer) |
| Containerized | 5-10s | 1-5s | Very High |

## Recommendation

**Start with**: Simplified mocks + In-memory repositories
- Fast feedback
- Realistic for data layer
- Easy to maintain

**Add later**: Containerized integration tests
- Before releases
- For critical flows
- In CI/CD pipeline


