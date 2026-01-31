import XCTest
@testable import FIN1

/// Simple test to identify the specific data flow issues
class SimpleFilterTest: XCTestCase {

    func testBasicFilterFlow() async throws {
        // Create a simple test case
        let mockDataGenerator = MockDataGenerator()
        let searchService = SecuritiesSearchService(mockDataGenerator: mockDataGenerator)
        let filterManager = SearchFilterService()
        let coordinator = SecuritiesSearchCoordinator(
            searchService: searchService,
            filterManager: filterManager
        )

        // Test a simple case: Apple Call
        filterManager.category = "Optionsschein"
        filterManager.underlyingAsset = "Apple"
        filterManager.direction = .call
        filterManager.strikePriceGap = nil
        filterManager.remainingTerm = nil
        filterManager.issuer = nil

        // Perform search
        await coordinator.performSearch()

        // Wait for async operations
        await TestHelpers.waitForAsync()

        // Check results
        print("🔍 Search results count: \(coordinator.searchResults.count)")
        print("🔍 Is loading: \(coordinator.isLoading)")
        print("🔍 Error message: \(coordinator.errorMessage ?? "None")")

        // Verify we get results
        XCTAssertFalse(coordinator.searchResults.isEmpty, "Should have search results")
        XCTAssertFalse(coordinator.isLoading, "Should not be loading")
        XCTAssertNil(coordinator.errorMessage, "Should not have error message")

        // Verify data integrity
        for result in coordinator.searchResults {
            print("🔍 Result: \(result.wkn) - \(result.direction ?? "nil") - \(result.underlyingAsset ?? "nil")")
            XCTAssertEqual(result.direction, "Call", "Result direction should be Call")
            XCTAssertEqual(result.underlyingAsset, "Apple", "Underlying asset should be Apple")
        }
    }

    func testStockFilterFlow() async throws {
        // Test stock case
        let mockDataGenerator = MockDataGenerator()
        let searchService = SecuritiesSearchService(mockDataGenerator: mockDataGenerator)
        let filterManager = SearchFilterService()
        let coordinator = SecuritiesSearchCoordinator(
            searchService: searchService,
            filterManager: filterManager
        )

        // Test a simple case: Apple Stock
        filterManager.category = "Aktie"
        filterManager.underlyingAsset = "Apple"
        filterManager.direction = .call // Should be ignored for stocks
        filterManager.strikePriceGap = nil
        filterManager.remainingTerm = nil
        filterManager.issuer = nil

        // Perform search
        await coordinator.performSearch()

        // Wait for async operations
        await TestHelpers.waitForAsync()

        // Check results
        print("🔍 Stock search results count: \(coordinator.searchResults.count)")
        print("🔍 Is loading: \(coordinator.isLoading)")
        print("🔍 Error message: \(coordinator.errorMessage ?? "None")")

        // Debug: Print all results
        for (index, result) in coordinator.searchResults.enumerated() {
            print("🔍 Result \(index): wkn=\(result.wkn), direction=\(result.direction ?? "nil"), underlyingAsset=\(result.underlyingAsset ?? "nil")")
        }

        // Verify we get results
        XCTAssertFalse(coordinator.searchResults.isEmpty, "Should have search results")
        XCTAssertFalse(coordinator.isLoading, "Should not be loading")
        XCTAssertNil(coordinator.errorMessage, "Should not have error message")

        // Verify data integrity
        for result in coordinator.searchResults {
            XCTAssertEqual(result.category, "Aktie", "Result category should be Aktie")
            XCTAssertEqual(result.underlyingAsset, "Apple", "Underlying asset should be Apple")
        }
    }

    func testRichtungDataFlow() async throws {
        // Test Call direction flow
        print("🔍 Testing Call direction flow...")

        let mockDataGenerator = MockDataGenerator()
        let searchService = SecuritiesSearchService(mockDataGenerator: mockDataGenerator)
        let filterManager = SearchFilterService()
        let coordinator = SecuritiesSearchCoordinator(
            searchService: searchService,
            filterManager: filterManager
        )

        // Given: Set up Call options search
        filterManager.category = "Optionsschein"
        filterManager.underlyingAsset = "DAX"
        filterManager.direction = .call

        // When: Perform search
        await coordinator.performSearch()
        await TestHelpers.waitForAsync()

        // Then: Verify Call results
        print("🔍 Call results count: \(coordinator.searchResults.count)")
        XCTAssertFalse(coordinator.searchResults.isEmpty, "Should have Call results")
        XCTAssertTrue(coordinator.searchResults.allSatisfy { $0.direction == "Call" }, "All results should be Call options")
        XCTAssertTrue(coordinator.searchResults.allSatisfy { $0.underlyingAsset == "DAX" }, "All results should be for DAX")

        // Store Call results for comparison
        let callResults = coordinator.searchResults

        // Test Put direction flow
        print("🔍 Testing Put direction flow...")

        // Given: Set up Put options search
        filterManager.category = "Optionsschein"
        filterManager.underlyingAsset = "DAX"
        filterManager.direction = .put

        // When: Perform search
        await coordinator.performSearch()
        await TestHelpers.waitForAsync()

        // Then: Verify Put results
        print("🔍 Put results count: \(coordinator.searchResults.count)")
        XCTAssertFalse(coordinator.searchResults.isEmpty, "Should have Put results")
        XCTAssertTrue(coordinator.searchResults.allSatisfy { $0.direction == "Put" }, "All results should be Put options")
        XCTAssertTrue(coordinator.searchResults.allSatisfy { $0.underlyingAsset == "DAX" }, "All results should be for DAX")

        // Store Put results for comparison
        let putResults = coordinator.searchResults

        // Test that Call and Put results are different
        XCTAssertFalse(callResults.isEmpty, "Should have Call results")
        XCTAssertFalse(putResults.isEmpty, "Should have Put results")
        XCTAssertNotEqual(callResults.count, putResults.count, "Call and Put should have different result counts")

        print("✅ Richtung data flow test passed!")
    }
}
