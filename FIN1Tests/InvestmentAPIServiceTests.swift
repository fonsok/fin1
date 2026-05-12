import XCTest
@testable import FIN1

// MARK: - Investment API Service Tests

final class InvestmentAPIServiceTests: XCTestCase {

    var sut: InvestmentAPIService!
    var mockAPIClient: MockParseAPIClient!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockParseAPIClient()
        sut = InvestmentAPIService(apiClient: mockAPIClient)
    }

    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        super.tearDown()
    }

    // MARK: - Save Investment Tests

    func testSaveInvestment_Success() async throws {
        // Given
        let investment = createSampleInvestment()
        mockAPIClient.mockObjectId = "server-investment-id-123"

        // When
        let savedInvestment = try await sut.saveInvestment(investment)

        // Then
        XCTAssertTrue(mockAPIClient.createObjectCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "Investment")
        XCTAssertEqual(savedInvestment.id, "server-investment-id-123")
        XCTAssertEqual(savedInvestment.investorId, investment.investorId)
        XCTAssertEqual(savedInvestment.amount, investment.amount)
    }

    func testSaveInvestment_PreservesAllFields() async throws {
        // Given
        let investment = createSampleInvestment()
        mockAPIClient.mockObjectId = "server-investment-id-456"

        // When
        let savedInvestment = try await sut.saveInvestment(investment)

        // Then
        XCTAssertEqual(savedInvestment.investorName, investment.investorName)
        XCTAssertEqual(savedInvestment.traderId, investment.traderId)
        XCTAssertEqual(savedInvestment.traderName, investment.traderName)
        XCTAssertEqual(savedInvestment.status, investment.status)
        XCTAssertEqual(savedInvestment.specialization, investment.specialization)
    }

    func testSaveInvestment_NetworkError() async {
        // Given
        let investment = createSampleInvestment()
        mockAPIClient.shouldThrowError = true
        mockAPIClient.errorToThrow = NetworkError.noConnection

        // When/Then
        do {
            _ = try await sut.saveInvestment(investment)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Update Investment Tests

    func testUpdateInvestment_Success() async throws {
        // Given
        let investment = createSampleInvestment(id: "existing-investment-id")

        // When
        let updatedInvestment = try await sut.updateInvestment(investment)

        // Then
        XCTAssertTrue(mockAPIClient.updateObjectCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "Investment")
        XCTAssertEqual(mockAPIClient.lastObjectId, "existing-investment-id")
        XCTAssertEqual(updatedInvestment.id, investment.id)
    }

    // MARK: - Fetch Investments Tests

    func testFetchInvestments_Success() async throws {
        // Given
        let investorId = "investor-123"
        let mockResponses = [
            createMockInvestmentResponse(objectId: "inv-1"),
            createMockInvestmentResponse(objectId: "inv-2"),
            createMockInvestmentResponse(objectId: "inv-3")
        ]
        mockAPIClient.mockFetchResults = mockResponses

        // When
        let investments = try await sut.fetchInvestments(for: investorId)

        // Then
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "Investment")
        XCTAssertEqual(investments.count, 3)
    }

    func testFetchInvestments_EmptyResult() async throws {
        // Given
        let investorId = "investor-no-investments"
        mockAPIClient.mockFetchResults = [ParseInvestment]()

        // When
        let investments = try await sut.fetchInvestments(for: investorId)

        // Then
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertTrue(investments.isEmpty)
    }

    // MARK: - Pool Participation Tests

    func testCreatePoolParticipation_Success() async throws {
        // Given
        let participation = createSamplePoolParticipation()
        mockAPIClient.mockObjectId = "server-participation-id-789"

        // When
        let savedParticipation = try await sut.createPoolParticipation(participation)

        // Then
        XCTAssertTrue(mockAPIClient.callFunctionCalled)
        XCTAssertEqual(mockAPIClient.lastFunctionName, "recordPoolTradeParticipation")
        XCTAssertEqual(savedParticipation.id, "server-participation-id-789")
        XCTAssertEqual(savedParticipation.tradeId, participation.tradeId)
        XCTAssertEqual(savedParticipation.investmentId, participation.investmentId)
    }

    func testUpdatePoolParticipation_Success() async throws {
        // Given
        let participation = createSamplePoolParticipation(id: "existing-participation-id")

        // When
        let updatedParticipation = try await sut.updatePoolParticipation(participation)

        // Then
        XCTAssertTrue(mockAPIClient.callFunctionCalled)
        XCTAssertEqual(mockAPIClient.lastFunctionName, "updatePoolTradeParticipation")
        XCTAssertEqual(updatedParticipation.id, participation.id)
    }

    // MARK: - Helper Methods

    private func createSampleInvestment(id: String = "local-investment-id") -> Investment {
        return Investment(
            id: id,
            batchId: "batch-123",
            investorId: "investor-123",
            investorName: "Max Mustermann",
            traderId: "trader-456",
            traderName: "Top Trader",
            amount: 10000.0,
            currentValue: 10500.0,
            date: Date(),
            status: .active,
            performance: 5.0,
            numberOfTrades: 3,
            sequenceNumber: 1,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil,
            specialization: "DAX Options",
            reservationStatus: .active
        )
    }

    private func createSamplePoolParticipation(id: String = "local-participation-id") -> PoolTradeParticipation {
        return PoolTradeParticipation(
            id: id,
            tradeId: "trade-123",
            investmentId: "investment-456",
            poolReservationId: "pool-789",
            poolNumber: 1,
            allocatedAmount: 5000.0,
            totalTradeValue: 50000.0,
            ownershipPercentage: 0.1,
            profitShare: nil
        )
    }

    private func createMockInvestmentResponse(objectId: String) -> ParseInvestment {
        ParseInvestment(
            objectId: objectId,
            investorId: "investor-123",
            investorName: "Max Mustermann",
            traderId: "trader-456",
            traderName: "Top Trader",
            amount: 10000.0,
            currentValue: 10500.0,
            status: "active",
            performance: 5.0,
            numberOfTrades: 3,
            batchId: "batch-123",
            sequenceNumber: 1,
            createdAt: FlexibleParseDate(dateString: "2026-02-04T10:00:00.000Z"),
            updatedAt: FlexibleParseDate(dateString: "2026-02-04T10:00:00.000Z"),
            completedAt: nil,
            activatedAt: nil,
            specialization: "DAX Options",
            reservationStatus: "active",
            profit: nil,
            profitPercentage: nil,
            investmentNumber: nil,
            partialSellCount: nil,
            realizedSellQuantity: nil,
            realizedSellAmount: nil,
            lastPartialSellAt: nil,
            tradeSellVolumeProgress: nil
        )
    }
}
