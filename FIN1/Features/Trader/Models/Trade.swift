import Foundation

// MARK: - Trade Model
/// **Trade** = Buy + Sell order results for investor pool distribution
struct Trade: Identifiable, Codable, Sendable {
    let id: String
    let tradeNumber: Int
    let tradeNumberYear: Int?
    let traderId: String
    let symbol: String
    let description: String
    let buyOrder: OrderBuy
    let sellOrder: OrderSell?
    let sellOrders: [OrderSell]
    let status: TradeStatus
    let createdAt: Date
    let completedAt: Date?
    let updatedAt: Date
    let calculatedProfit: Double?
    let traderPartialSellEventCount: Int?
    let buyLegType: String?
    let pairExecutionId: String?

    enum CodingKeys: String, CodingKey {
        case id, tradeNumber, tradeNumberYear, traderId, symbol, description, buyOrder, sellOrder, sellOrders, status
        case createdAt, completedAt, updatedAt, calculatedProfit, traderPartialSellEventCount
        case buyLegType, pairExecutionId
    }

    init(
        id: String,
        tradeNumber: Int,
        tradeNumberYear: Int? = nil,
        traderId: String,
        symbol: String,
        description: String,
        buyOrder: OrderBuy,
        sellOrder: OrderSell?,
        sellOrders: [OrderSell],
        status: TradeStatus,
        createdAt: Date,
        completedAt: Date?,
        updatedAt: Date,
        calculatedProfit: Double? = nil,
        traderPartialSellEventCount: Int? = nil,
        buyLegType: String? = nil,
        pairExecutionId: String? = nil
    ) {
        self.id = id
        self.tradeNumber = tradeNumber
        self.tradeNumberYear = tradeNumberYear
        self.traderId = traderId
        self.symbol = symbol
        self.description = description
        self.buyOrder = buyOrder
        self.sellOrder = sellOrder
        self.sellOrders = sellOrders
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.calculatedProfit = calculatedProfit
        self.traderPartialSellEventCount = traderPartialSellEventCount
        self.buyLegType = buyLegType
        self.pairExecutionId = pairExecutionId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.tradeNumber = try container.decodeIfPresent(Int.self, forKey: .tradeNumber) ?? 0
        self.tradeNumberYear = try container.decodeIfPresent(Int.self, forKey: .tradeNumberYear)
        self.traderId = try container.decode(String.self, forKey: .traderId)
        self.symbol = try container.decode(String.self, forKey: .symbol)
        self.description = try container.decode(String.self, forKey: .description)
        self.buyOrder = try container.decode(OrderBuy.self, forKey: .buyOrder)
        self.sellOrder = try container.decodeIfPresent(OrderSell.self, forKey: .sellOrder)
        self.sellOrders = try container.decodeIfPresent([OrderSell].self, forKey: .sellOrders) ?? []
        self.status = try container.decode(TradeStatus.self, forKey: .status)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.calculatedProfit = try container.decodeIfPresent(Double.self, forKey: .calculatedProfit)
        self.traderPartialSellEventCount = try container.decodeIfPresent(Int.self, forKey: .traderPartialSellEventCount)
        self.buyLegType = try container.decodeIfPresent(String.self, forKey: .buyLegType)
        self.pairExecutionId = try container.decodeIfPresent(String.self, forKey: .pairExecutionId)
    }

    var optionDirection: String? { self.buyOrder.optionDirection }
    var underlyingAsset: String? { self.buyOrder.underlyingAsset }
    var wkn: String? { self.buyOrder.wkn }

    var resolvedTradeNumberYear: Int {
        self.tradeNumberYear ?? TradeNumberFormatting.calendarYear(for: self.createdAt)
    }

    var formattedTradeNumber: String {
        TradeNumberFormatting.display(number: self.tradeNumber, year: self.resolvedTradeNumberYear)
    }

    var totalQuantity: Double { self.buyOrder.quantity }
    var entryPrice: Double { self.buyOrder.price }

    var exitPrice: Double? {
        if let latestSellOrder = sellOrders.last {
            return latestSellOrder.price
        }
        return self.sellOrder?.price
    }

    var duration: TimeInterval? {
        guard let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(self.buyOrder.createdAt)
    }
}
