@testable import FIN1
import XCTest

final class TraderDepotTradeFilterTests: XCTestCase {
    func testExcludesMirrorPoolLegByBuyLegType() {
        let mirror = self.makeTrade(id: "m", buyLegType: "MIRROR_POOL")
        let trader = self.makeTrade(id: "t", buyLegType: "TRADER")

        let result = TraderDepotTradeFilter.tradesForDepotDisplay([mirror, trader])

        XCTAssertEqual(result.map(\.id), ["t"])
    }

    func testExcludesMirrorPoolLegByBuyOrderFlag() {
        let mirror = self.makeTrade(id: "m", isMirrorPoolOrder: true)
        let trader = self.makeTrade(id: "t", isMirrorPoolOrder: false)

        let result = TraderDepotTradeFilter.tradesForDepotDisplay([mirror, trader])

        XCTAssertEqual(result.map(\.id), ["t"])
    }

    func testKeepsLegacyStandaloneBuy() {
        let legacy = self.makeTrade(id: "l", buyLegType: nil, isMirrorPoolOrder: nil)

        let result = TraderDepotTradeFilter.tradesForDepotDisplay([legacy])

        XCTAssertEqual(result.map(\.id), ["l"])
    }

    // MARK: - Helpers

    private func makeTrade(
        id: String,
        buyLegType: String? = "TRADER",
        isMirrorPoolOrder: Bool? = false
    ) -> Trade {
        let now = Date()
        let buyOrder = OrderBuy(
            id: "order-\(id)",
            traderId: "trader-1",
            symbol: "UB4PQLG",
            description: "Euro Stoxx 50",
            quantity: 10,
            price: 1.64,
            totalAmount: 16.4,
            status: .executed,
            createdAt: now,
            executedAt: now,
            confirmedAt: nil,
            updatedAt: now,
            optionDirection: "Put",
            underlyingAsset: "Euro Stoxx 50",
            wkn: "UB4PQLG",
            category: nil,
            strike: 10_500,
            orderInstruction: "market",
            limitPrice: nil,
            isMirrorPoolOrder: isMirrorPoolOrder
        )

        return Trade(
            id: id,
            tradeNumber: 1,
            traderId: "trader-1",
            symbol: "UB4PQLG",
            description: "Euro Stoxx 50",
            buyOrder: buyOrder,
            sellOrder: nil,
            sellOrders: [],
            status: .active,
            createdAt: now,
            completedAt: nil,
            updatedAt: now,
            buyLegType: buyLegType,
            pairExecutionId: "pair-1"
        )
    }
}
