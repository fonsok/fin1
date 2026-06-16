@testable import FIN1
import Foundation
import XCTest

final class TradeInvestorCommissionNameResolverTests: XCTestCase {

    private func investment(
        id: String,
        investorId: String,
        investorName: String,
        investmentNumber: String? = nil
    ) -> Investment {
        Investment(
            id: id,
            investmentNumber: investmentNumber,
            batchId: nil,
            investorId: investorId,
            investorName: investorName,
            traderId: "trader-1",
            traderUsername: nil,
            traderName: "Trader",
            amount: 1_000,
            currentValue: 1_000,
            date: Date(),
            status: .completed,
            performance: 0,
            numberOfTrades: 1,
            sequenceNumber: nil,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: Date(),
            specialization: "",
            reservationStatus: .active,
            partialSellCount: 0,
            realizedSellQuantity: 0,
            realizedSellAmount: 0,
            lastPartialSellAt: nil,
            tradeSellVolumeProgress: nil,
            poolTradingAmount: nil
        )
    }

    func test_prefersServerNameWhenPresent() {
        let name = TradeInvestorCommissionNameResolver.resolve(
            serverName: "dbraun",
            investmentId: "inv-1",
            investorId: "user-1",
            investments: []
        )
        XCTAssertEqual(name, "dbraun")
    }

    func test_resolvesByInvestmentIdThenInvestorId() {
        let investments = [
            self.investment(id: "inv-a", investorId: "inv-user-a", investorName: "dbraun"),
            self.investment(id: "inv-b", investorId: "inv-user-b", investorName: "oschneider"),
        ]
        XCTAssertEqual(
            TradeInvestorCommissionNameResolver.resolve(
                investmentId: "inv-a",
                investorId: "inv-user-a",
                investments: investments
            ),
            "dbraun"
        )
        XCTAssertEqual(
            TradeInvestorCommissionNameResolver.resolve(
                investmentId: nil,
                investorId: "inv-user-b",
                investments: investments
            ),
            "oschneider"
        )
    }

    func test_fallsBackToInvestmentNumberBeforeGenericInvestor() {
        let investments = [
            self.investment(
                id: "inv-a",
                investorId: "inv-user-a",
                investorName: "",
                investmentNumber: "INV-2026-0000002"
            ),
        ]
        XCTAssertEqual(
            TradeInvestorCommissionNameResolver.resolve(
                investmentId: "inv-a",
                investorId: "inv-user-a",
                investments: investments
            ),
            "INV-2026-0000002"
        )
    }
}
