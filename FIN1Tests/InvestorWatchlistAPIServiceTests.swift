import XCTest
@testable import FIN1

// MARK: - Investor Watchlist API Service Tests

final class InvestorWatchlistAPIServiceTests: XCTestCase {

    var sut: InvestorWatchlistAPIService!
    var mockAPIClient: MockParseAPIClient!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockParseAPIClient()
        sut = InvestorWatchlistAPIService(apiClient: mockAPIClient)
    }

    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        super.tearDown()
    }

    // MARK: - Save Watchlist Item Tests

    func testSaveWatchlistItem_Success() async throws {
        // Given
        let trader = createSampleWatchlistTrader()
        let investorId = "investor-123"
        mockAPIClient.mockObjectId = "server-watchlist-id-123"

        // When
        let savedItem = try await sut.saveWatchlistItem(trader, investorId: investorId)

        // Then
        XCTAssertTrue(mockAPIClient.createObjectCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "InvestorWatchlist")
        XCTAssertEqual(savedItem.id, trader.id)
        XCTAssertEqual(savedItem.name, trader.name)
    }

    func testSaveWatchlistItem_PreservesAllFields() async throws {
        // Given
        let trader = createSampleWatchlistTrader()
        let investorId = "investor-456"

        // When
        let savedItem = try await sut.saveWatchlistItem(trader, investorId: investorId)

        // Then
        XCTAssertEqual(savedItem.riskClass, trader.riskClass)
        XCTAssertEqual(savedItem.notificationsEnabled, trader.notificationsEnabled)
        XCTAssertEqual(savedItem.isActive, trader.isActive)
    }

    func testSaveWatchlistItem_NetworkError() async {
        // Given
        let trader = createSampleWatchlistTrader()
        let investorId = "investor-123"
        mockAPIClient.shouldThrowError = true
        mockAPIClient.errorToThrow = NetworkError.noConnection

        // When/Then
        do {
            _ = try await sut.saveWatchlistItem(trader, investorId: investorId)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Remove Watchlist Item Tests

    func testRemoveWatchlistItem_Success() async throws {
        // Given
        let traderId = "trader-to-remove"
        let investorId = "investor-123"
        let mockResponse = createMockWatchlistResponse(objectId: "parse-object-id", traderId: traderId)
        mockAPIClient.mockFetchResults = [mockResponse]

        // When
        try await sut.removeWatchlistItem(traderId, investorId: investorId)

        // Then
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertTrue(mockAPIClient.deleteObjectCalled)
        XCTAssertEqual(mockAPIClient.lastObjectId, "parse-object-id")
    }

    func testRemoveWatchlistItem_NotFound_NoError() async throws {
        // Given
        let traderId = "trader-not-in-watchlist"
        let investorId = "investor-123"
        mockAPIClient.mockFetchResults = [MockWatchlistResponse]()

        // When/Then - Should not throw
        try await sut.removeWatchlistItem(traderId, investorId: investorId)
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertFalse(mockAPIClient.deleteObjectCalled)
    }

    func testRemoveWatchlistItem_NetworkError() async {
        // Given
        let traderId = "trader-123"
        let investorId = "investor-123"
        mockAPIClient.shouldThrowError = true
        mockAPIClient.errorToThrow = NetworkError.serverError(500)

        // When/Then
        do {
            try await sut.removeWatchlistItem(traderId, investorId: investorId)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Fetch Watchlist Tests

    func testFetchWatchlist_Success() async throws {
        // Given
        let investorId = "investor-123"
        let mockResponses = [
            createMockWatchlistResponse(objectId: "item-1", traderId: "trader-1"),
            createMockWatchlistResponse(objectId: "item-2", traderId: "trader-2"),
            createMockWatchlistResponse(objectId: "item-3", traderId: "trader-3")
        ]
        mockAPIClient.mockFetchResults = mockResponses

        // When
        let watchlist = try await sut.fetchWatchlist(for: investorId)

        // Then
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "InvestorWatchlist")
        XCTAssertEqual(watchlist.count, 3)
    }

    func testFetchWatchlist_EmptyResult() async throws {
        // Given
        let investorId = "investor-with-empty-watchlist"
        mockAPIClient.mockFetchResults = [MockWatchlistResponse]()

        // When
        let watchlist = try await sut.fetchWatchlist(for: investorId)

        // Then
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertTrue(watchlist.isEmpty)
    }

    func testFetchWatchlist_ParsesTraderData() async throws {
        // Given
        let investorId = "investor-123"
        let mockResponse = createMockWatchlistResponse(
            objectId: "item-1",
            traderId: "trader-premium",
            traderName: "Premium Trader",
            riskClass: 3
        )
        mockAPIClient.mockFetchResults = [mockResponse]

        // When
        let watchlist = try await sut.fetchWatchlist(for: investorId)

        // Then
        XCTAssertEqual(watchlist.count, 1)
        XCTAssertEqual(watchlist.first?.id, "trader-premium")
        XCTAssertEqual(watchlist.first?.name, "Premium Trader")
        XCTAssertEqual(watchlist.first?.riskClass.rawValue, 3)
    }

    // MARK: - Helper Methods

    private func createSampleWatchlistTrader(id: String = "trader-123") -> WatchlistTraderData {
        return WatchlistTraderData(
            id: id,
            name: "Top Performer",
            image: "trader_image.png",
            performance: 25.5,
            riskClass: .riskClass2,
            totalInvestors: 150,
            minimumInvestment: 5000.0,
            description: "Expert in DAX options trading",
            tradingStrategy: "Conservative growth strategy",
            experience: "5 years",
            dateAdded: Date(),
            lastUpdated: Date(),
            isActive: true,
            notificationsEnabled: true
        )
    }

    private func createMockWatchlistResponse(
        objectId: String,
        traderId: String,
        traderName: String = "Test Trader",
        riskClass: Int = 2
    ) -> MockWatchlistResponse {
        return MockWatchlistResponse(
            objectId: objectId,
            investorId: "investor-123",
            traderId: traderId,
            traderName: traderName,
            traderSpecialization: "DAX Options",
            traderRiskClass: riskClass,
            notes: nil,
            targetInvestmentAmount: 10000.0,
            notifyOnNewTrade: true,
            notifyOnPerformanceChange: true,
            sortOrder: 0,
            addedAt: "2026-02-05T10:00:00.000Z"
        )
    }
}

// MARK: - Mock Watchlist Response

private struct MockWatchlistResponse: Codable {
    let objectId: String
    let investorId: String
    let traderId: String
    let traderName: String
    let traderSpecialization: String?
    let traderRiskClass: Int?
    let notes: String?
    let targetInvestmentAmount: Double?
    let notifyOnNewTrade: Bool
    let notifyOnPerformanceChange: Bool
    let sortOrder: Int
    let addedAt: String
}
