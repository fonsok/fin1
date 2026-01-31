import XCTest
@testable import FIN1

// MARK: - Commission Calculation Service Tests

final class CommissionCalculationServiceTests: XCTestCase {

    var service: CommissionCalculationService!
    var mockInvestorGrossProfitService: MockInvestorGrossProfitService!

    override func setUp() {
        super.setUp()

        mockInvestorGrossProfitService = MockInvestorGrossProfitService()
        service = CommissionCalculationService(investorGrossProfitService: mockInvestorGrossProfitService)
    }

    override func tearDown() {
        service = nil
        mockInvestorGrossProfitService = nil
        super.tearDown()
    }

    // MARK: - Basic Commission Calculations

    func testCalculateCommission_WithPositiveGrossProfit_ReturnsCommission() {
        // Given
        let grossProfit = 1000.0
        let rate = 0.1

        // When
        let result = service.calculateCommission(grossProfit: grossProfit, rate: rate)

        // Then
        XCTAssertEqual(result, 100.0, accuracy: 0.01)
    }

    func testCalculateCommission_WithZeroGrossProfit_ReturnsZero() {
        // Given
        let grossProfit = 0.0
        let rate = 0.1

        // When
        let result = service.calculateCommission(grossProfit: grossProfit, rate: rate)

        // Then
        XCTAssertEqual(result, 0.0)
    }

    func testCalculateCommission_WithNegativeGrossProfit_ReturnsZero() {
        // Given
        let grossProfit = -100.0
        let rate = 0.1

        // When
        let result = service.calculateCommission(grossProfit: grossProfit, rate: rate)

        // Then
        XCTAssertEqual(result, 0.0)
    }

    func testCalculateNetProfitAfterCommission_WithPositiveGrossProfit_ReturnsNetProfit() {
        // Given
        let grossProfit = 1000.0
        let rate = 0.1

        // When
        let result = service.calculateNetProfitAfterCommission(grossProfit: grossProfit, rate: rate)

        // Then
        XCTAssertEqual(result, 900.0, accuracy: 0.01)
    }

    func testCalculateCommissionAndNetProfit_WithPositiveGrossProfit_ReturnsBoth() {
        // Given
        let grossProfit = 1000.0
        let rate = 0.1

        // When
        let result = service.calculateCommissionAndNetProfit(grossProfit: grossProfit, rate: rate)

        // Then
        XCTAssertEqual(result.commission, 100.0, accuracy: 0.01)
        XCTAssertEqual(result.netProfit, 900.0, accuracy: 0.01)
    }

    // MARK: - Investor-Specific Commission Calculations

    func testCalculateCommissionForInvestor_WithValidData_ReturnsCommission() async throws {
        // Given
        let investmentId = "investment-1"
        let tradeId = "trade-1"
        let commissionRate = 0.1
        let expectedGrossProfit = 1000.0
        let expectedCommission = 100.0

        mockInvestorGrossProfitService.getGrossProfitHandler = { invId, trId in
            XCTAssertEqual(invId, investmentId)
            XCTAssertEqual(trId, tradeId)
            return expectedGrossProfit
        }

        // When
        let result = try await service.calculateCommissionForInvestor(
            investmentId: investmentId,
            tradeId: tradeId,
            commissionRate: commissionRate
        )

        // Then
        XCTAssertEqual(result, expectedCommission, accuracy: 0.01)
    }

    func testCalculateTotalCommissionForTrade_WithMultipleInvestors_ReturnsSum() async throws {
        // Given
        let tradeId = "trade-1"
        let commissionRate = 0.1

        mockInvestorGrossProfitService.getGrossProfitsForTradeHandler = { trId in
            XCTAssertEqual(trId, tradeId)
            return [
                "investment-1": 1000.0,
                "investment-2": 500.0
            ]
        }

        // When
        let result = try await service.calculateTotalCommissionForTrade(
            tradeId: tradeId,
            commissionRate: commissionRate
        )

        // Then
        // Expected: (1000.0 * 0.1) + (500.0 * 0.1) = 100.0 + 50.0 = 150.0
        XCTAssertEqual(result, 150.0, accuracy: 0.01)
    }

    func testCalculateCommissionForInvestor_WithServiceUnavailable_ThrowsError() async {
        // Given
        let serviceWithoutGrossProfit = CommissionCalculationService(investorGrossProfitService: nil)
        let investmentId = "investment-1"
        let tradeId = "trade-1"
        let commissionRate = 0.1

        // When/Then
        do {
            _ = try await serviceWithoutGrossProfit.calculateCommissionForInvestor(
                investmentId: investmentId,
                tradeId: tradeId,
                commissionRate: commissionRate
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }
}

// MARK: - Mock Services

class MockInvestorGrossProfitService: InvestorGrossProfitServiceProtocol {
    var getGrossProfitHandler: ((String, String) async throws -> Double)?
    var getGrossProfitsForTradeHandler: ((String) async throws -> [String: Double])?

    func start() {}
    func stop() {}
    func reset() {}

    func getGrossProfit(for investmentId: String, tradeId: String) async throws -> Double {
        if let handler = getGrossProfitHandler {
            return try await handler(investmentId, tradeId)
        }
        throw AppError.serviceError(.dataNotFound)
    }

    func getGrossProfitsForTrade(tradeId: String) async throws -> [String: Double] {
        if let handler = getGrossProfitsForTradeHandler {
            return try await handler(tradeId)
        }
        return [:]
    }
}











