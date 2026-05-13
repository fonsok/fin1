@testable import FIN1
import XCTest

@MainActor
final class MockInvestmentStatusServiceTests: XCTestCase {

    func testDefaultMarkActiveIncrementsCountAndReturnsNil() {
        let mock = MockInvestmentStatusService()
        let repo = InvestmentRepository()

        let result = mock.markInvestmentAsActive(
            for: "trader-1",
            repository: repo,
            investmentPoolLifecycleService: nil,
            telemetryService: nil
        )

        XCTAssertNil(result)
        XCTAssertEqual(mock.markInvestmentAsActiveCallCount, 1)
        XCTAssertEqual(mock.lastMarkActiveTraderId, "trader-1")
    }

    func testHandlerOverridesReturnValue() {
        let mock = MockInvestmentStatusService()
        let repo = InvestmentRepository()
        let expected = Investment(
            id: "inv-1",
            batchId: nil,
            investorId: "inv",
            investorName: "I",
            traderId: "t",
            traderName: "T",
            amount: 100,
            currentValue: 100,
            date: Date(),
            status: .active,
            performance: 0,
            numberOfTrades: 0,
            sequenceNumber: 1,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil,
            specialization: "S",
            reservationStatus: .active
        )
        mock.markInvestmentAsActiveHandler = { _, _, _, _ in expected }

        let result = mock.markInvestmentAsActive(
            for: "x",
            repository: repo,
            investmentPoolLifecycleService: nil,
            telemetryService: nil
        )

        XCTAssertEqual(result?.id, expected.id)
    }

    func testResetClearsState() {
        let mock = MockInvestmentStatusService()
        let repo = InvestmentRepository()
        _ = mock.deleteInvestment(investmentId: "a", repository: repo)
        XCTAssertEqual(mock.deleteInvestmentCallCount, 1)

        mock.reset()

        XCTAssertEqual(mock.deleteInvestmentCallCount, 0)
        XCTAssertNil(mock.lastDeleteInvestmentId)
    }
}
