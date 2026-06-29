@testable import FIN1
import XCTest

final class SearchResultDepotHoldingTests: XCTestCase {
    func testInitFromDepotHoldingMapsTradingMetadata() {
        let holding = DepotHolding(
            orderId: "order-1",
            position: 1,
            valuationDate: "15.03.2025",
            wkn: "CI17GVU",
            strike: 38_700,
            designation: "Call - DAX",
            direction: "Call",
            underlyingAsset: "DAX",
            purchasePrice: 1.66,
            currentPrice: 1.72,
            quantity: 100,
            originalQuantity: 100,
            soldQuantity: 0,
            remainingQuantity: 100,
            totalValue: 172,
            denomination: 1,
            subscriptionRatio: 0.01
        )

        let result = SearchResult(depotHolding: holding)

        XCTAssertEqual(result.wkn, "CI17GVU")
        XCTAssertEqual(result.direction, "Call")
        XCTAssertEqual(result.underlyingAsset, "DAX")
        XCTAssertEqual(result.denomination, 1)
        XCTAssertEqual(result.subscriptionRatio, 0.01)
        XCTAssertFalse(result.askPrice.isEmpty)
        XCTAssertFalse(result.strike.isEmpty)
    }
}
