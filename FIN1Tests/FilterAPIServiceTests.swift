@testable import FIN1
import XCTest

// MARK: - Filter API Service Tests

final class FilterAPIServiceTests: XCTestCase {

    var sut: FilterAPIService!
    var mockAPIClient: MockParseAPIClient!

    override func setUp() {
        super.setUp()
        self.mockAPIClient = MockParseAPIClient()
        self.sut = FilterAPIService(apiClient: self.mockAPIClient)
    }

    override func tearDown() {
        self.sut = nil
        self.mockAPIClient = nil
        super.tearDown()
    }

    // MARK: - Save Securities Filter Tests

    func testSaveSecuritiesFilter_Success() async throws {
        // Given
        let filter = self.createSampleSecuritiesFilter()
        let userId = "test-user-123"

        // When
        let savedFilter = try await sut.saveSecuritiesFilter(filter, userId: userId)

        // Then
        XCTAssertTrue(self.mockAPIClient.createObjectCalled)
        XCTAssertEqual(self.mockAPIClient.lastClassName, "SavedFilter")
        XCTAssertEqual(savedFilter.name, filter.name)
        XCTAssertEqual(savedFilter.isDefault, filter.isDefault)
    }

    func testSaveSecuritiesFilter_NetworkError() async {
        // Given
        let filter = self.createSampleSecuritiesFilter()
        let userId = "test-user-123"
        self.mockAPIClient.shouldThrowError = true
        self.mockAPIClient.errorToThrow = NetworkError.noConnection

        // When/Then
        do {
            _ = try await self.sut.saveSecuritiesFilter(filter, userId: userId)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Save Trader Filter Tests

    func testSaveTraderFilter_Success() async throws {
        // Given
        let filter = self.createSampleTraderFilter()
        let userId = "test-user-123"

        // When
        let savedFilter = try await sut.saveTraderFilter(filter, userId: userId)

        // Then
        XCTAssertTrue(self.mockAPIClient.createObjectCalled)
        XCTAssertEqual(self.mockAPIClient.lastClassName, "SavedFilter")
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
        self.mockAPIClient.mockFetchResults = mockResponses

        // When
        let filters = try await sut.fetchSecuritiesFilters(for: userId)

        // Then
        XCTAssertTrue(self.mockAPIClient.fetchObjectsCalled)
        XCTAssertEqual(self.mockAPIClient.lastClassName, "SavedFilter")
        XCTAssertEqual(filters.count, 2)
    }

    func testFetchSecuritiesFilters_EmptyResult() async throws {
        // Given
        let userId = "test-user-no-filters"
        self.mockAPIClient.mockFetchResults = [ParseFilterResponse]()

        // When
        let filters = try await sut.fetchSecuritiesFilters(for: userId)

        // Then
        XCTAssertTrue(self.mockAPIClient.fetchObjectsCalled)
        XCTAssertTrue(filters.isEmpty)
    }

    // MARK: - Fetch Trader Filters Tests

    func testFetchTraderFilters_Success() async throws {
        // Given
        let userId = "test-user-123"
        let mockResponses = [
            createMockTraderFilterResponse(objectId: "filter-1", name: "High Performers")
        ]
        self.mockAPIClient.mockFetchResults = mockResponses

        // When
        let filters = try await sut.fetchTraderFilters(for: userId)

        // Then
        XCTAssertTrue(self.mockAPIClient.fetchObjectsCalled)
        XCTAssertEqual(self.mockAPIClient.lastClassName, "SavedFilter")
        XCTAssertEqual(filters.count, 1)
    }

    // MARK: - Delete Filter Tests

    func testDeleteFilter_Success() async throws {
        // Given
        let filterId = "filter-to-delete"
        let userId = "test-user-123"
        let mockResponse = self.createMockSecuritiesFilterResponse(objectId: "parse-object-id")
        self.mockAPIClient.mockFetchResults = [mockResponse]

        // When
        try await self.sut.deleteFilter(filterId, context: .securitiesSearch, userId: userId)

        // Then
        XCTAssertTrue(self.mockAPIClient.fetchObjectsCalled)
        XCTAssertTrue(self.mockAPIClient.deleteObjectCalled)
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

    private func createMockSecuritiesFilterResponse(objectId: String, name: String = "Test Filter") -> ParseFilterResponse {
        ParseFilterResponse(
            objectId: objectId,
            userId: "test-user-123",
            name: name,
            filterContext: FilterContext.securitiesSearch.rawValue,
            filterCriteria: [
                "category": AnyCodable("DAX"),
                "underlyingAsset": AnyCodable("BMW"),
                "direction": AnyCodable("Call")
            ],
            isDefault: false,
            createdAt: "2026-02-05T10:00:00.000Z",
            updatedAt: "2026-02-05T10:00:00.000Z"
        )
    }

    private func createMockTraderFilterResponse(objectId: String, name: String = "Test Filter") -> ParseFilterResponse {
        ParseFilterResponse(
            objectId: objectId,
            userId: "test-user-123",
            name: name,
            filterContext: FilterContext.traderDiscovery.rawValue,
            filterCriteria: [
                IndividualFilterCriteria.FilterType.recentSuccessfulTrades.rawValue: AnyCodable(FilterSuccessRateOption.tenOutOfTen.rawValue)
            ],
            isDefault: false,
            createdAt: "2026-02-05T10:00:00.000Z",
            updatedAt: "2026-02-05T10:00:00.000Z"
        )
    }
}
