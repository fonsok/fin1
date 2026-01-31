@testable import FIN1
import XCTest

final class CompletedInvestmentDetailViewModelTests: XCTestCase {
    func testFinancialMetrics_ComputesProfitTaxesAndNetOutcome() {
        // Given
        let investment = makeInvestment(
            amount: 1_000,
            currentValue: 1_250,
            status: .completed,
            completedAt: Date()
        )
        let viewModel = CompletedInvestmentDetailViewModel(investment: investment)

        // When
        let profit = viewModel.profit
        let provision = viewModel.provisionAmount
        let totalTax = viewModel.totalTaxAmount
        let netProfit = viewModel.netProfitAfterCharges

        // Then
        XCTAssertEqual(profit, 250, accuracy: 0.001)
        XCTAssertEqual(provision, 15, accuracy: 0.001) // 1.5% platform service charge
        XCTAssertEqual(totalTax, 70.9375, accuracy: 0.0001)
        XCTAssertEqual(netProfit, 164.0625, accuracy: 0.0001)
        XCTAssertTrue(viewModel.isProfitPositive)
        XCTAssertTrue(viewModel.hasPositiveNetProfit)
    }

    func testSummaryMetadata_FormatsInvestmentDetails() {
        // Given
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let investment = makeInvestment(
            id: "1234567890",
            traderName: "Test Trader",
            amount: 2_000,
            currentValue: 1_500,
            status: .cancelled,
            createdAt: date,
            completedAt: date,
            reservedPools: [
                PoolReservation(
                    id: "pool-1",
                    poolNumber: 2,
                    status: .completed,
                    actualPoolId: "actual-1",
                    allocatedAmount: 500,
                    reservedAt: date,
                    isLocked: true
                )
            ]
        )
        let viewModel = CompletedInvestmentDetailViewModel(investment: investment)

        // Then
        XCTAssertEqual(viewModel.investmentNumber, "12345678")
        XCTAssertEqual(viewModel.traderName, "Test Trader")
        XCTAssertEqual(viewModel.statusText, InvestmentStatus.cancelled.displayName)
        XCTAssertEqual(viewModel.numberOfPoolsText, "1")
        XCTAssertEqual(viewModel.completedPoolCountText, "1")
        XCTAssertEqual(viewModel.activePoolCountText, "0")
        XCTAssertTrue(viewModel.hasPoolDetails)
        XCTAssertEqual(viewModel.poolDetails.first?.poolNumber, 2)
        XCTAssertEqual(viewModel.poolDetails.first?.amountText, 500.formattedAsLocalizedCurrency())
    }

    // MARK: - Helpers

    private func makeInvestment(
        id: String = UUID().uuidString,
        traderName: String = "Anna",
        amount: Double,
        currentValue: Double,
        status: InvestmentStatus,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        reservedPools: [PoolReservation] = []
    ) -> Investment {
        Investment(
            id: id,
            investorId: "investor-1",
            traderId: "trader-1",
            traderName: traderName,
            amount: amount,
            currentValue: currentValue,
            date: createdAt,
            status: status,
            performance: amount == 0 ? 0 : ((currentValue - amount) / amount) * 100,
            numberOfTrades: 3,
            numberOfPools: max(reservedPools.count, 1),
            createdAt: createdAt,
            updatedAt: createdAt,
            completedAt: completedAt,
            specialization: "Quantitative Strategies",
            reservedPoolSlots: reservedPools
        )
    }
}
