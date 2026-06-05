@testable import FIN1
import XCTest

/// End-to-end contract: buy-sheet quantity → combined calculation → placement payload fields.
final class BuyOrderQuantityPipelineTests: XCTestCase {
    private let calculationService = InvestmentQuantityCalculationService()

    /// Regression: warrant-style product (Brief 1,64 €, Bezugsverhältnis 0,01) must not cap 1000 → 60.
    func testPipelineKeepsTraderQuantityForExecutePairedBuyPayload() {
        let userEnteredPieces = 1_000
        let briefPrice = 1.64
        let subscriptionRatio = 0.01

        let combined = self.calculationService.calculateCombinedOrderDetails(
            traderQuantity: userEnteredPieces,
            traderCashBalance: 10_000,
            investmentBalance: 3_000,
            pricePerSecurity: briefPrice,
            subscriptionRatio: subscriptionRatio
        )

        // Mirrors BuyOrderPlacementService.placeOrder resolution
        let traderQuantity = combined.traderQuantity
        let mirrorPoolQuantity = combined.investmentQuantity
        let estimatedCost = OrderCashAmount.grossAmount(
            quantity: traderQuantity,
            briefPricePerPiece: briefPrice
        )

        XCTAssertEqual(traderQuantity, userEnteredPieces, "executePairedBuy traderQuantity")
        XCTAssertFalse(combined.isTraderLimited)
        XCTAssertEqual(estimatedCost, 1_640, accuracy: 0.01)
        XCTAssertGreaterThan(mirrorPoolQuantity, 100, "pool mirror should use full brief-price affordability")
        XCTAssertEqual(
            OrderCashAmount.grossAmount(quantity: traderQuantity, briefPricePerPiece: briefPrice),
            combined.traderOrderAmount,
            accuracy: 0.01
        )
    }
}
