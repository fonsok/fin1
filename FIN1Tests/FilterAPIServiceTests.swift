import XCTest
@testable import FIN1

// MARK: - Filter API Service Tests

final class FilterAPIServiceTests: XCTestCase {

    var sut: FilterAPIService!
    var mockAPIClient: MockParseAPIClient!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockParseAPIClient()
        sut = FilterAPIService(apiClient: mockAPIClient)
    }

    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        super.tearDown()
    }

    // MARK: - Save Securities Filter Tests

    func testSaveSecuritiesFilter_Success() async throws {
        // Given
        let filter = createSampleSecuritiesFilter()
        let userId = "test-user-123"

        // When
        let savedFilter = try await sut.saveSecuritiesFilter(filter, userId: userId)

        // Then
        XCTAssertTrue(mockAPIClient.createObjectCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "SavedFilter")
        XCTAssertEqual(savedFilter.name, filter.name)
        XCTAssertEqual(savedFilter.isDefault, filter.isDefault)
    }

    func testSaveSecuritiesFilter_NetworkError() async {
        // Given
        let filter = createSampleSecuritiesFilter()
        let userId = "test-user-123"
        mockAPIClient.shouldThrowError = true
        mockAPIClient.errorToThrow = NetworkError.noConnection

        // When/Then
        do {
            _ = try await sut.saveSecuritiesFilter(filter, userId: userId)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Save Trader Filter Tests

    func testSaveTraderFilter_Success() async throws {
        // Given
        let filter = createSampleTraderFilter()
        let userId = "test-user-123"

        // When
        let savedFilter = try await sut.saveTraderFilter(filter, userId: userId)

        // Then
        XCTAssertTrue(mockAPIClient.createObjectCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "SavedFilter")
        XCTAssertEqual(savedFilter.name, filter.name)
        XCTAssertEqual(savedFilter.isDefault, filter.isDefault)
    }

    // MARK: - Fetch Securities Filters Tests

    func testFetchSecuritiesFilters_Success() async throws {
        // Given
        let userId = "test-user-123"
        let mockResponses = [
            createMockSecuritiesFilterResponse(objectId: "filter-1", name: "Tech Filter"),
            createMockSecuritiesFilterResponse(objectId: "filter-2", name: "Value Filter")
        ]
        mockAPIClient.mockFetchResults = mockResponses

        // When
        let filters = try await sut.fetchSecuritiesFilters(for: userId)

        // Then
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "SavedFilter")
        XCTAssertEqual(filters.count, 2)
    }

    func testFetchSecuritiesFilters_EmptyResult() async throws {
        // Given
        let userId = "test-user-no-filters"
        mockAPIClient.mockFetchResults = [MockSecuritiesFilterResponse]()

        // When
        let filters = try await sut.fetchSecuritiesFilters(for: userId)

        // Then
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertTrue(filters.isEmpty)
    }

    // MARK: - Fetch Trader Filters Tests

    func testFetchTraderFilters_Success() async throws {
        // Given
        let userId = "test-user-123"
        let mockResponses = [
            createMockTraderFilterResponse(objectId: "filter-1", name: "High Performers")
        ]
        mockAPIClient.mockFetchResults = mockResponses

        // When
        let filters = try await sut.fetchTraderFilters(for: userId)

        // Then
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "SavedFilter")
        XCTAssertEqual(filters.count, 1)
    }

    // MARK: - Delete Filter Tests

    func testDeleteFilter_Success() async throws {
        // Given
        let filterId = "filter-to-delete"
        let userId = "test-user-123"
        let mockResponse = createMockSecuritiesFilterResponse(objectId: "parse-object-id")
        mockAPIClient.mockFetchResults = [mockResponse]

        // When
        try await sut.deleteFilter(filterId, context: .securitiesSearch, userId: userId)

        // Then
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertTrue(mockAPIClient.deleteObjectCalled)
    }

    // MARK: - Helper Methods

    private func createSampleSecuritiesFilter() -> SecuritiesFilterCombination {
        let searchFilters = SearchFilters(
            category: "DAX",
            underlyingAsset: "BMW",
            direction: .call,
            strikePriceGap: "5%",
            remainingTerm: "30",
            issuer: "Deutsche Bank",
            omega: nil
        )
        return SecuritiesFilterCombination(
            name: "Test Filter",
            filters: searchFilters,
            isDefault: false
        )
    }

    private func createSampleTraderFilter() -> FilterCombination {
        let criteria = [
            IndividualFilterCriteria(type: .returnRate, returnPercentageOption: .greaterThan80)
        ]
        return FilterCombination(
            name: "High Success Traders",
            filters: criteria,
            isDefault: false
        )
    }

    private func createMockSecuritiesFilterResponse(objectId: String, name: String = "Test Filter") -> MockSecuritiesFilterResponse {
        return MockSecuritiesFilterResponse(
            objectId: objectId,
            userId: "test-user-123",
            name: name,
            filterContext: "securities_search",
            filterCriteria: [
                "category": "DAX",
                "underlyingAsset": "BMW",
                "direction": "call"
            ],
            isDefault: false,
            createdAt: "2026-02-05T10:00:00.000Z",
            updatedAt: "2026-02-05T10:00:00.000Z"
        )
    }

    private func createMockTraderFilterResponse(objectId: String, name: String = "Test Filter") -> MockTraderFilterResponse {
        return MockTraderFilterResponse(
            objectId: objectId,
            userId: "test-user-123",
            name: name,
            filterContext: "trader_discovery",
            filterCriteria: [
                "successRate": "above80"
            ],
            isDefault: false,
            createdAt: "2026-02-05T10:00:00.000Z",
            updatedAt: "2026-02-05T10:00:00.000Z"
        )
    }
}

// MARK: - Mock Filter Responses

private struct MockSecuritiesFilterResponse: Codable {
    let objectId: String
    let userId: String
    let name: String
    let filterContext: String
    let filterCriteria: [String: String]
    let isDefault: Bool
    let createdAt: String
    let updatedAt: String
}

private struct MockTraderFilterResponse: Codable {
    let objectId: String
    let userId: String
    let name: String
    let filterContext: String
    let filterCriteria: [String: String]
    let isDefault: Bool
    let createdAt: String
    let updatedAt: String
}
