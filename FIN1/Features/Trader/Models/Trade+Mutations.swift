import Foundation

extension Trade {
    static func from(buyOrder: OrderBuy, tradeNumber: Int, tradeNumberYear: Int? = nil) -> Trade {
        Trade(
            id: UUID().uuidString,
            tradeNumber: tradeNumber,
            tradeNumberYear: tradeNumberYear ?? TradeNumberFormatting.calendarYear(for: buyOrder.createdAt),
            traderId: buyOrder.traderId,
            symbol: buyOrder.symbol,
            description: buyOrder.description,
            buyOrder: buyOrder,
            sellOrder: nil,
            sellOrders: [],
            status: .pending,
            createdAt: buyOrder.createdAt,
            completedAt: nil,
            updatedAt: buyOrder.updatedAt
        )
    }

    func with(sellOrder: OrderSell) -> Trade {
        Trade(
            id: self.id,
            tradeNumber: self.tradeNumber,
            tradeNumberYear: self.tradeNumberYear,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            buyOrder: self.buyOrder,
            sellOrder: sellOrder,
            sellOrders: self.sellOrders + [sellOrder],
            status: .active,
            createdAt: self.createdAt,
            completedAt: nil,
            updatedAt: sellOrder.updatedAt
        )
    }

    func withPartialSellOrder(_ sellOrder: OrderSell) -> Trade {
        Trade(
            id: self.id,
            tradeNumber: self.tradeNumber,
            tradeNumberYear: self.tradeNumberYear,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            buyOrder: self.buyOrder,
            sellOrder: self.sellOrder,
            sellOrders: self.sellOrders + [sellOrder],
            status: .active,
            createdAt: self.createdAt,
            completedAt: nil,
            updatedAt: sellOrder.updatedAt,
            calculatedProfit: self.calculatedProfit,
            traderPartialSellEventCount: self.traderPartialSellEventCount
        )
    }

    func updateStatus() -> Trade {
        let newStatus = self.computedStatus
        let isCompleted = newStatus == .completed

        return Trade(
            id: self.id,
            tradeNumber: self.tradeNumber,
            tradeNumberYear: self.tradeNumberYear,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            buyOrder: self.buyOrder,
            sellOrder: self.sellOrder,
            sellOrders: self.sellOrders,
            status: newStatus,
            createdAt: self.createdAt,
            completedAt: isCompleted ? Date() : nil,
            updatedAt: Date(),
            calculatedProfit: self.calculatedProfit,
            traderPartialSellEventCount: self.traderPartialSellEventCount
        )
    }

    func withCalculatedProfit(_ profit: Double) -> Trade {
        Trade(
            id: self.id,
            tradeNumber: self.tradeNumber,
            tradeNumberYear: self.tradeNumberYear,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            buyOrder: self.buyOrder,
            sellOrder: self.sellOrder,
            sellOrders: self.sellOrders,
            status: self.status,
            createdAt: self.createdAt,
            completedAt: self.completedAt,
            updatedAt: Date(),
            calculatedProfit: profit
        )
    }
}
