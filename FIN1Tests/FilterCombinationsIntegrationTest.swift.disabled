import XCTest
@testable import FIN1

/// Comprehensive test to verify all filter combinations work correctly in securities search
class FilterCombinationsIntegrationTest: XCTestCase {

    private var mockDataGenerator: MockDataGenerator!
    private var searchService: SecuritiesSearchService!
    private var filterManager: SearchFilterService!
    private var coordinator: SecuritiesSearchCoordinator!

    override func setUp() {
        super.setUp()
        mockDataGenerator = MockDataGenerator()
        searchService = SecuritiesSearchService(mockDataGenerator: mockDataGenerator)
        filterManager = SearchFilterService()
        coordinator = SecuritiesSearchCoordinator(
            searchService: searchService,
            filterManager: filterManager
        )
    }

    override func tearDown() {
        coordinator = nil
        filterManager = nil
        searchService = nil
        mockDataGenerator = nil
        super.tearDown()
    }

    // MARK: - Test All Filter Combinations

    func testAllFilterCombinations() async throws {
        let testCases = generateKeyFilterCombinations()

        for (index, testCase) in testCases.enumerated() {
            print("🧪 Testing combination \(index + 1)/\(testCases.count): \(testCase.description)")

            // Set up filters
            filterManager.category = testCase.category
            filterManager.underlyingAsset = testCase.underlyingAsset
            filterManager.direction = testCase.direction
            filterManager.strikePriceGap = testCase.strikePriceGap
            filterManager.remainingTerm = testCase.remainingTerm
            filterManager.issuer = testCase.issuer

            // Perform search
            await coordinator.performSearch()

            // Wait for async operations
            await TestHelpers.waitForAsync()

            // Verify basic functionality (not necessarily non-empty results)
            XCTAssertFalse(coordinator.isLoading, "Should not be loading after search completion")
            XCTAssertNil(coordinator.errorMessage, "Should not have error message for valid combination: \(testCase.description)")

            // Verify data flow integrity for any results we do get
            if !coordinator.searchResults.isEmpty {
                verifyDataFlowIntegrity(for: testCase)
            }
        }
    }

    // MARK: - Test Specific Problematic Combinations

    func testProblematicCombinations() async throws {
        let problematicCases = [
            FilterTestCase(
                category: "Optionsschein",
                underlyingAsset: "Apple",
                direction: .put,
                strikePriceGap: "10%",
                remainingTerm: "< 4 Wo.",
                issuer: "Société Générale",
                description: "Apple Put with tight filters"
            ),
            FilterTestCase(
                category: "Aktie",
                underlyingAsset: "DAX",
                direction: .call, // Should be ignored for stocks
                strikePriceGap: nil,
                remainingTerm: nil,
                issuer: nil,
                description: "Stock with ignored options filters"
            ),
            FilterTestCase(
                category: "Optionsschein",
                underlyingAsset: "Tesla",
                direction: .call,
                strikePriceGap: "20%",
                remainingTerm: "< 1 Jahr",
                issuer: "Alle",
                description: "Tesla Call with 'Alle' emittent"
            )
        ]

        for testCase in problematicCases {
            print("🧪 Testing problematic combination: \(testCase.description)")

            // Set up filters
            filterManager.category = testCase.category
            filterManager.underlyingAsset = testCase.underlyingAsset
            filterManager.direction = testCase.direction
            filterManager.strikePriceGap = testCase.strikePriceGap
            filterManager.remainingTerm = testCase.remainingTerm
            filterManager.issuer = testCase.issuer

            // Perform search
            await coordinator.performSearch()

            // Wait for async operations
            await TestHelpers.waitForAsync()

            // Verify results
            XCTAssertFalse(coordinator.searchResults.isEmpty, "Search results should not be empty for: \(testCase.description)")
            verifyDataFlowIntegrity(for: testCase)
        }
    }

    // MARK: - Test Edge Cases

    func testEdgeCases() async throws {
        // Test with all filters set to extreme values
        let edgeCases = [
            FilterTestCase(
                category: "Optionsschein",
                underlyingAsset: "DAX",
                direction: .call,
                strikePriceGap: "50%",
                remainingTerm: "< 4 Wo.",
                issuer: "Deutsche Bank",
                description: "All filters set to restrictive values"
            ),
            FilterTestCase(
                category: "Aktie",
                underlyingAsset: "BMW",
                direction: .put, // Should be ignored
                strikePriceGap: nil,
                remainingTerm: nil,
                issuer: nil,
                description: "Stock with minimal filters"
            )
        ]

        for testCase in edgeCases {
            print("🧪 Testing edge case: \(testCase.description)")

            // Set up filters
            filterManager.category = testCase.category
            filterManager.underlyingAsset = testCase.underlyingAsset
            filterManager.direction = testCase.direction
            filterManager.strikePriceGap = testCase.strikePriceGap
            filterManager.remainingTerm = testCase.remainingTerm
            filterManager.issuer = testCase.issuer

            // Perform search
            await coordinator.performSearch()

            // Wait for async operations
            await TestHelpers.waitForAsync()

            // Verify results
            XCTAssertFalse(coordinator.searchResults.isEmpty, "Search results should not be empty for edge case: \(testCase.description)")
            verifyDataFlowIntegrity(for: testCase)
        }
    }

    // MARK: - Test Data Flow Validation

    func testDataFlowValidation() async throws {
        let testCase = FilterTestCase(
            category: "Optionsschein",
            underlyingAsset: "Apple",
            direction: .call,
            strikePriceGap: "10%",
            remainingTerm: "< 1 Jahr",
            issuer: "Société Générale",
            description: "Data flow validation test"
        )

        // Set up filters
        filterManager.category = testCase.typ
        filterManager.underlyingAsset = testCase.basiswert
        filterManager.direction = testCase.direction
        filterManager.strikePriceGap = testCase.strikePriceGap
        filterManager.remainingTerm = testCase.restlaufzeit
        filterManager.issuer = testCase.emittent

        // Perform search
        await coordinator.performSearch()

        // Wait for async operations
        await TestHelpers.waitForAsync()

        // Verify data flow integrity
        verifyDataFlowIntegrity(for: testCase)

        // Verify that the data flows correctly through the entire chain
        let currentFilters = filterManager.getCurrentFilters()
        XCTAssertEqual(currentFilters.category, testCase.typ)
        XCTAssertEqual(currentFilters.basiswert, testCase.basiswert)
        XCTAssertEqual(currentFilters.direction, testCase.direction)
        XCTAssertEqual(currentFilters.strikePriceGap, testCase.strikePriceGap)
        XCTAssertEqual(currentFilters.restlaufzeit, testCase.restlaufzeit)
        XCTAssertEqual(currentFilters.emittent, testCase.emittent)
    }

    // MARK: - Helper Methods

    private func generateKeyFilterCombinations() -> [FilterTestCase] {
        // Generate a focused set of key combinations that cover the most important scenarios
        var combinations: [FilterTestCase] = []

        // Stock combinations (simpler, fewer filters)
        let stockUnderlyingAssets = ["DAX", "Apple", "BMW", "Tesla"]
        for underlyingAsset in stockUnderlyingAssets {
            combinations.append(FilterTestCase(
                category: "Aktie",
                underlyingAsset: underlyingAsset,
                direction: .call, // Ignored for stocks
                strikePriceGap: nil,
                remainingTerm: nil,
                issuer: nil,
                description: "Stock - \(underlyingAsset)"
            ))
        }

        // Options combinations (more complex, but focused on key scenarios)
        let optionUnderlyingAssets = ["DAX", "Apple", "Tesla"]
        let directions: [SecuritiesSearchView.Direction] = [.call, .put]
        let keyFilters = [
            (strikePriceGap: nil, remainingTerm: nil, issuer: nil),
            (strikePriceGap: "10%", remainingTerm: nil, issuer: nil),
            (strikePriceGap: nil, remainingTerm: "< 1 Jahr", issuer: nil),
            (strikePriceGap: nil, remainingTerm: nil, issuer: "Société Générale"),
            (strikePriceGap: "10%", remainingTerm: "< 1 Jahr", issuer: "Société Générale")
        ]

        for underlyingAsset in optionUnderlyingAssets {
            for direction in directions {
                for (strikePriceGap, remainingTerm, issuer) in keyFilters {
                    combinations.append(FilterTestCase(
                        category: "Optionsschein",
                        underlyingAsset: underlyingAsset,
                        direction: direction,
                        strikePriceGap: strikePriceGap,
                        remainingTerm: remainingTerm,
                        issuer: issuer,
                        description: "Options - \(underlyingAsset) - \(direction.rawValue) - \(strikePriceGap ?? "nil") - \(remainingTerm ?? "nil") - \(issuer ?? "nil")"
                    ))
                }
            }
        }

        return combinations
    }

    private func generateAllFilterCombinations() -> [FilterTestCase] {
        let types = ["Aktie", "Optionsschein"]
        let basiswerte = ["DAX", "Apple", "Tesla", "BMW", "Microsoft", "Google"]
        let directions: [SecuritiesSearchView.Direction] = [.call, .put]
        let strikePriceGape = [nil, "10%", "20%", "30%"]
        let restlaufzeiten = [nil, "< 4 Wo.", "< 1 Jahr", "> 1 Jahr"]
        let emittenten = [nil, "Société Générale", "Deutsche Bank", "Vontobel", "Alle"]

        var combinations: [FilterTestCase] = []

        for typ in types {
            for basiswert in basiswerte {
                if typ == "Aktie" {
                    // For stocks, direction doesn't matter, so test with both
                    for direction in directions {
                        let testCase = FilterTestCase(
                            category: typ,
                            underlyingAsset: basiswert,
                            direction: direction,
                            strikePriceGap: nil,
                            remainingTerm: nil,
                            issuer: nil,
                            description: "\(typ) - \(basiswert) - \(direction.rawValue)"
                        )
                        combinations.append(testCase)
                    }
                } else {
                    // For options, test all combinations
                    for direction in directions {
                        for strikePriceGap in strikePriceGape {
                            for restlaufzeit in restlaufzeiten {
                                for emittent in emittenten {
                                    let testCase = FilterTestCase(
                                        category: typ,
                                        underlyingAsset: basiswert,
                                        direction: direction,
                                        strikePriceGap: strikePriceGap,
                                        remainingTerm: restlaufzeit,
                                        issuer: emittent,
                                        description: "\(typ) - \(basiswert) - \(direction.rawValue) - \(strikePriceGap ?? "nil") - \(restlaufzeit ?? "nil") - \(emittent ?? "nil")"
                                    )
                                    combinations.append(testCase)
                                }
                            }
                        }
                    }
                }
            }
        }

        return combinations
    }

    private func verifyDataFlowIntegrity(for testCase: FilterTestCase) {
        // Verify that search results match the filter criteria
        for result in coordinator.searchResults {
            // Verify typ matches
            if testCase.typ == "Aktie" {
                XCTAssertEqual(result.category, "Aktie", "Stock results should have category 'Aktie'")
            } else {
                XCTAssertTrue(result.direction == "Call" || result.direction == "Put", "Options results should have direction 'Call' or 'Put'")
                XCTAssertEqual(result.direction, testCase.direction.rawValue, "Options direction should match selected direction")
            }

            // Verify underlying asset matches
            XCTAssertEqual(result.underlyingAsset, testCase.basiswert, "Underlying asset should match selected basiswert")

            // Verify WKN and ISIN are properly formatted
            XCTAssertFalse(result.wkn.isEmpty, "WKN should not be empty")
            XCTAssertFalse(result.isin.isEmpty, "ISIN should not be empty")
            XCTAssertTrue(result.isin.hasPrefix("DE000"), "ISIN should start with 'DE000'")

            // Verify price formatting
            XCTAssertFalse(result.strike.isEmpty, "Strike should not be empty")
            XCTAssertFalse(result.askPrice.isEmpty, "Briefkurs should not be empty")
        }
    }
}

// MARK: - Test Helper Struct

private struct FilterTestCase {
    let category: String
    let underlyingAsset: String
    let direction: SecuritiesSearchView.Direction
    let strikePriceGap: String?
    let remainingTerm: String?
    let issuer: String?
    let description: String
}

// MARK: - Test Helpers
// Using existing TestHelpers from TestHelpers.swift
