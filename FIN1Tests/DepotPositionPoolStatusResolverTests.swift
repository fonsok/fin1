@testable import FIN1
import XCTest

final class DepotPositionPoolStatusResolverTests: XCTestCase {

    func testLegacyPositionShowsInactive() {
        let holding = self.makeHolding(tradeId: "legacy-1", pairExecutionId: nil)
        let isActive = DepotPositionPoolStatusResolver.isPoolActive(
            for: holding,
            completedTrades: [self.makeTrade(id: "legacy-1", pairExecutionId: nil)],
            participations: []
        )
        XCTAssertFalse(isActive)
        XCTAssertEqual(
            DepotPositionPoolStatusResolver.displayValue(
                for: holding,
                completedTrades: [],
                participations: []
            ),
            "-"
        )
    }

    func testPairedBuyWithMirrorLegShowsActive() {
        let pairId = "pair-abc"
        let holding = self.makeHolding(tradeId: "trader-leg", pairExecutionId: pairId)
        let trades = [
            self.makeTrade(id: "trader-leg", buyLegType: "TRADER", pairExecutionId: pairId),
            self.makeTrade(id: "mirror-leg", buyLegType: "MIRROR_POOL", pairExecutionId: pairId)
        ]

        XCTAssertTrue(
            DepotPositionPoolStatusResolver.isPoolActive(
                for: holding,
                completedTrades: trades,
                participations: []
            )
        )
    }

    func testRecordedParticipationShowsActive() {
        let holding = self.makeHolding(tradeId: "trade-42", pairExecutionId: nil)
        let participation = PoolTradeParticipation(
            tradeId: "trade-42",
            investmentId: "inv-1",
            poolReservationId: "inv-1",
            poolNumber: 1,
            allocatedAmount: 100,
            totalTradeValue: 500
        )

        XCTAssertTrue(
            DepotPositionPoolStatusResolver.isPoolActive(
                for: holding,
                completedTrades: [],
                participations: [participation]
            )
        )
    }

    // MARK: - Helpers

    private func makeHolding(tradeId: String, pairExecutionId: String?) -> DepotHolding {
        DepotHolding(
            orderId: "order-\(tradeId)",
            tradeId: tradeId,
            pairExecutionId: pairExecutionId,
            position: 1,
            valuationDate: "01.01.2026",
            wkn: "UB4PQLG",
            strike: 10_500,
            designation: "Put - Euro Stoxx 50",
            direction: "Put",
            underlyingAsset: "Euro Stoxx 50",
            purchasePrice: 1.64,
            currentPrice: 1.64,
            quantity: 10,
            originalQuantity: 10,
            soldQuantity: 0,
            remainingQuantity: 10,
            totalValue: 16.4
        )
    }

    private func makeTrade(
        id: String,
        buyLegType: String? = "TRADER",
        pairExecutionId: String? = nil,
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
            pairExecutionId: pairExecutionId
        )
    }
}
