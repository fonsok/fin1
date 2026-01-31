import XCTest
@testable import FIN1

/// Tests to ensure the basiswert filter logic remains intact
/// These tests should catch any regressions in the filter functionality
class BasiswertFilterTests: XCTestCase {

    var mockDataGenerator: MockDataGenerator!
    var searchService: SecuritiesSearchService!

    override func setUp() {
        super.setUp()
        mockDataGenerator = MockDataGenerator()
        searchService = SecuritiesSearchService(mockDataGenerator: MockDataGenerator())
    }

    override func tearDown() {
        mockDataGenerator = nil
        searchService = nil
        super.tearDown()
    }

    // MARK: - Basiswert Filter Tests

    func testBasiswertFilterWithFTSE100() async {
        // Given: FTSE 100 selected as basiswert
        let filters = SearchFilters(
            category: "Optionsschein",
            underlyingAsset: "FTSE 100",
            direction: .call,
            strikePriceGap: nil,
            remainingTerm: nil,
            issuer: nil,
            omega: nil
        )

        // When: Generating search results
        let results = mockDataGenerator.generateOptionsResults(for: filters)

        // Then: All results should have FTSE 100 as underlying asset
        XCTAssertFalse(results.isEmpty, "Should generate results for FTSE 100")

        for result in results {
            XCTAssertEqual(result.underlyingAsset, "FTSE 100",
                          "Result should have FTSE 100 as underlying asset, but got: \(result.underlyingAsset ?? "nil")")
        }
    }

    func testBasiswertFilterWithCAC40() async {
        // Given: CAC 40 selected as basiswert
        let filters = SearchFilters(
            category: "Optionsschein",
            underlyingAsset: "CAC 40",
            direction: .put,
            strikePriceGap: nil,
            remainingTerm: nil,
            issuer: nil,
            omega: nil
        )

        // When: Generating search results
        let results = mockDataGenerator.generateOptionsResults(for: filters)

        // Then: All results should have CAC 40 as underlying asset
        XCTAssertFalse(results.isEmpty, "Should generate results for CAC 40")

        for result in results {
            XCTAssertEqual(result.underlyingAsset, "CAC 40",
                          "Result should have CAC 40 as underlying asset, but got: \(result.underlyingAsset ?? "nil")")
        }
    }

    func testBasiswertFilterWithDAX() async {
        // Given: DAX selected as basiswert
        let filters = SearchFilters(
            category: "Optionsschein",
            underlyingAsset: "DAX",
            direction: .call,
            strikePriceGap: nil,
            remainingTerm: nil,
            issuer: nil,
            omega: nil
        )

        // When: Generating search results
        let results = mockDataGenerator.generateOptionsResults(for: filters)

        // Then: All results should have DAX as underlying asset
        XCTAssertFalse(results.isEmpty, "Should generate results for DAX")

        for result in results {
            XCTAssertEqual(result.underlyingAsset, "DAX",
                          "Result should have DAX as underlying asset, but got: \(result.underlyingAsset ?? "nil")")
        }
    }

    func testEmptyBasiswertFallback() async {
        // Given: Empty basiswert (should fallback to DAX)
        let filters = SearchFilters(
            category: "Optionsschein",
            underlyingAsset: "",
            direction: .call,
            strikePriceGap: nil,
            remainingTerm: nil,
            issuer: nil,
            omega: nil
        )

        // When: Generating search results
        let results = mockDataGenerator.generateOptionsResults(for: filters)

        // Then: All results should have DAX as underlying asset (fallback)
        XCTAssertFalse(results.isEmpty, "Should generate results with DAX fallback")

        for result in results {
            XCTAssertEqual(result.underlyingAsset, "DAX",
                          "Result should have DAX as underlying asset (fallback), but got: \(result.underlyingAsset ?? "nil")")
        }
    }

    func testSearchResultInitializerWithValidUnderlyingAsset() {
        // Given: Valid underlying asset provided
        let underlyingAsset = "FTSE 100"

        // When: Creating SearchResult
        let result = SearchResult(
            valuationDate: "31.12.2025",
            wkn: "SG123456",
            strike: "100.00",
            askPrice: "1.50",
            direction: "Call",
            category: "Optionsschein",
            underlyingType: "Index",
            isin: "FR0012345678",
            underlyingAsset: underlyingAsset
        )

        // Then: Should use provided underlying asset
        XCTAssertEqual(result.underlyingAsset, underlyingAsset,
                      "Should use provided underlying asset: \(underlyingAsset)")
    }

    func testSearchResultInitializerWithEmptyUnderlyingAsset() {
        // Given: Empty underlying asset provided
        let underlyingAsset = ""

        // When: Creating SearchResult
        let result = SearchResult(
            valuationDate: "31.12.2025",
            wkn: "SG123456",
            strike: "100.00",
            askPrice: "1.50",
            direction: "Call",
            category: "Optionsschein",
            underlyingType: "Index",
            isin: "FR0012345678",
            underlyingAsset: underlyingAsset
        )

        // Then: Should fallback to WKN mapping
        XCTAssertNotNil(result.underlyingAsset, "Should have fallback underlying asset")
        XCTAssertNotEqual(result.underlyingAsset, "", "Should not be empty string")
    }

    func testSearchResultInitializerWithNilUnderlyingAsset() {
        // Given: Nil underlying asset provided
        let underlyingAsset: String? = nil

        // When: Creating SearchResult
        let result = SearchResult(
            valuationDate: "31.12.2025",
            wkn: "SG123456",
            strike: "100.00",
            askPrice: "1.50",
            direction: "Call",
            category: "Optionsschein",
            underlyingType: "Index",
            isin: "FR0012345678",
            underlyingAsset: underlyingAsset
        )

        // Then: Should fallback to WKN mapping
        XCTAssertNotNil(result.underlyingAsset, "Should have fallback underlying asset")
        XCTAssertNotEqual(result.underlyingAsset, "", "Should not be empty string")
    }

    // MARK: - Integration Tests

    func testFullSearchFlowWithBasiswertFilter() async {
        // Given: Search service with FTSE 100 filter
        let filters = SearchFilters(
            category: "Optionsschein",
            underlyingAsset: "FTSE 100",
            direction: .call,
            strikePriceGap: nil,
            remainingTerm: nil,
            issuer: nil,
            omega: nil
        )

        // When: Performing search
        await searchService.performSearch(with: filters)

        // Then: Results should be filtered correctly
        let results = searchService.searchResults
        XCTAssertFalse(results.isEmpty, "Should have search results")

        for result in results {
            XCTAssertEqual(result.underlyingAsset, "FTSE 100",
                          "Search result should have FTSE 100 as underlying asset, but got: \(result.underlyingAsset ?? "nil")")
        }
    }

    func testSearchResultsClearedOnNewSearch() async {
        // Given: Initial search with DAX
        let initialFilters = SearchFilters(
            category: "Optionsschein",
            underlyingAsset: "DAX",
            direction: .call,
            strikePriceGap: nil,
            remainingTerm: nil,
            issuer: nil,
            omega: nil
        )

        await searchService.performSearch(with: initialFilters)
        let initialResults = searchService.searchResults
        XCTAssertFalse(initialResults.isEmpty, "Should have initial results")

        // When: New search with FTSE 100
        let newFilters = SearchFilters(
            category: "Optionsschein",
            underlyingAsset: "FTSE 100",
            direction: .call,
            strikePriceGap: nil,
            remainingTerm: nil,
            issuer: nil,
            omega: nil
        )

        await searchService.performSearch(with: newFilters)

        // Then: Results should be updated (not mixed)
        let newResults = searchService.searchResults
        XCTAssertFalse(newResults.isEmpty, "Should have new results")

        for result in newResults {
            XCTAssertEqual(result.underlyingAsset, "FTSE 100",
                          "New search result should have FTSE 100 as underlying asset, but got: \(result.underlyingAsset ?? "nil")")
        }
    }
}
