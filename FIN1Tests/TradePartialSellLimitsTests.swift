@testable import FIN1
import XCTest

final class TradePartialSellLimitsTests: XCTestCase {

    func testLastAllowedPartialSellMustClearDepot() throws {
        let trade = Self.makeTrade(
            buyQty: 1_000,
            sellQtys: [200, 500],
            partialSellEventCount: 2
        )
        let partialSell = Self.makeSellOrder(quantity: 100)
        XCTAssertThrowsError(
            try trade.validatePartialSellAllowed(sellOrder: partialSell, maxPartialSells: 3)
        ) { error in
            guard case TradePartialSellLimitError.finalPartialSellMustClearDepot = error else {
                return XCTFail("Expected finalPartialSellMustClearDepot, got \(error)")
            }
        }
    }

    func testLastAllowedPartialSellFullRemainingAllowed() throws {
        let trade = Self.makeTrade(
            buyQty: 1_000,
            sellQtys: [200, 500],
            partialSellEventCount: 2
        )
        let fullExit = Self.makeSellOrder(quantity: 300)
        XCTAssertNoThrow(
            try trade.validatePartialSellAllowed(sellOrder: fullExit, maxPartialSells: 3)
        )
    }

    func testIntermediatePartialSellStillAllowed() throws {
        let trade = Self.makeTrade(
            buyQty: 1_000,
            sellQtys: [200],
            partialSellEventCount: 1
        )
        let partialSell = Self.makeSellOrder(quantity: 500)
        XCTAssertNoThrow(
            try trade.validatePartialSellAllowed(sellOrder: partialSell, maxPartialSells: 3)
        )
    }

    private static func makeSellOrder(quantity: Double) -> OrderSell {
        OrderSell(
            id: UUID().uuidString,
            traderId: "trader-1",
            symbol: "HS4PMLC",
            description: "Call - S&P 500",
            quantity: quantity,
            price: 5,
            totalAmount: quantity * 5,
            status: .confirmed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: "Call",
            underlyingAsset: "S&P 500",
            wkn: "HS4PMLC",
            category: nil,
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil,
            originalHoldingId: "buy-1"
        )
    }

    private static func makeTrade(
        buyQty: Double,
        sellQtys: [Double],
        partialSellEventCount: Int
    ) -> Trade {
        let now = Date()
        let buyOrder = OrderBuy(
            id: "buy-1",
            traderId: "trader-1",
            symbol: "HS4PMLC",
            description: "Call - S&P 500",
            quantity: buyQty,
            price: 5,
            totalAmount: buyQty * 5,
            status: .executed,
            createdAt: now,
            executedAt: now,
            confirmedAt: now,
            updatedAt: now,
            optionDirection: "Call",
            underlyingAsset: "S&P 500",
            wkn: "HS4PMLC",
            category: nil,
            strike: nil,
            orderInstruction: nil,
            limitPrice: nil
        )
        let sellOrders = sellQtys.enumerated().map { index, qty in
            OrderSell(
                id: "sell-\(index + 1)",
                traderId: "trader-1",
                symbol: "HS4PMLC",
                description: "Call - S&P 500",
                quantity: qty,
                price: 5,
                totalAmount: qty * 5,
                status: .completed,
                createdAt: now,
                executedAt: now,
                confirmedAt: now,
                updatedAt: now,
                optionDirection: "Call",
                underlyingAsset: "S&P 500",
                wkn: "HS4PMLC",
                category: nil,
                strike: nil,
                orderInstruction: nil,
                limitPrice: nil,
                originalHoldingId: "buy-1"
            )
        }
        return Trade(
            id: "trade-3",
            tradeNumber: 3,
            traderId: "trader-1",
            symbol: "HS4PMLC",
            description: "Call - S&P 500",
            buyOrder: buyOrder,
            sellOrder: nil,
            sellOrders: sellOrders,
            status: .active,
            createdAt: now,
            completedAt: nil,
            updatedAt: now,
            traderPartialSellEventCount: partialSellEventCount
        )
    }
}
