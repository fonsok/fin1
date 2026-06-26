@testable import FIN1
import XCTest

final class HoldingCardTilesPoolStatusTests: XCTestCase {

    func testIncludesPoolTileWhenStatusProvided() {
        let tiles = HoldingCardTiles.generateTiles(
            for: self.makeHolding(),
            warrantDetailsViewModel: WarrantDetailsViewModel(),
            poolStatusDisplay: "active"
        )

        XCTAssertTrue(tiles.contains(where: { $0.title == "Investment-Pool" && $0.value == "active" }))
    }

    func testOmitsPoolTileWhenStatusNil() {
        let tiles = HoldingCardTiles.generateTiles(
            for: self.makeHolding(),
            warrantDetailsViewModel: WarrantDetailsViewModel(),
            poolStatusDisplay: nil
        )

        XCTAssertFalse(tiles.contains(where: { $0.title == "Investment-Pool" }))
    }

    // MARK: - Helpers

    private func makeHolding() -> DepotHolding {
        DepotHolding(
            orderId: "order-1",
            tradeId: "trade-1",
            pairExecutionId: "pair-1",
            position: 1,
            valuationDate: "25.6.2026",
            wkn: "CI4YLSD",
            strike: 45_100,
            designation: "Put - NASDAQ 100",
            direction: "Put",
            underlyingAsset: "NASDAQ 100",
            purchasePrice: 7.29,
            currentPrice: 7.29,
            quantity: 1_000,
            originalQuantity: 1_000,
            soldQuantity: 0,
            remainingQuantity: 1_000,
            totalValue: 7_290
        )
    }
}
