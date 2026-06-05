@testable import FIN1
import XCTest

final class InvestmentQuantityCalculationServiceTests: XCTestCase {
    private let service = InvestmentQuantityCalculationService()

    /// Regression: UB4PQLG-style warrant — Brief-Kurs 1,64 €, Bezugsverhältnis 0,01 must not inflate cash per Stück to 164 €.
    func testMaxPurchasableUsesBriefKursNotSubscriptionInflatedUnitPrice() {
        let maxQty = self.service.calculateMaxPurchasableQuantity(
            investmentBalance: 10_000,
            pricePerSecurity: 1.64,
            denomination: nil,
            subscriptionRatio: 0.01
        )

        XCTAssertGreaterThanOrEqual(maxQty, 1_000, "€10k @ €1,64/Stück must afford at least 1000 Stück")
    }

    func testCombinedOrderKeepsTraderInput1000Stuck() {
        let result = self.service.calculateCombinedOrderDetails(
            traderQuantity: 1_000,
            traderCashBalance: 10_000,
            investmentBalance: 3_000,
            pricePerSecurity: 1.64,
            denomination: nil,
            subscriptionRatio: 0.01
        )

        XCTAssertEqual(result.traderQuantity, 1_000)
        XCTAssertFalse(result.isTraderLimited)
        XCTAssertGreaterThan(result.investmentQuantity, 18, "Pool @ €3000 should buy far more than 18 Stück")
    }
}
