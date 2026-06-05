import Foundation

/// Parse Server representation of a Trade
/// Maps between Parse format and app Trade model
struct ParseTrade: Decodable {
    let objectId: String
    let tradeNumber: Int
    let traderId: String
    let symbol: String
    let description: String
    let status: String
    let createdAt: String
    let updatedAt: String
    let completedAt: String?
    let calculatedProfit: Double?
    /// Server SSOT (`Trade.traderPartialSellEventCount` from beforeSave).
    let traderPartialSellEventCount: Int?
    let buyLegType: String?
    let pairExecutionId: String?
    let buyOrder: ParseOrderBuy
    let sellOrder: ParseOrderSell?
    let sellOrders: [ParseOrderSell]?

    enum CodingKeys: String, CodingKey {
        case objectId, tradeNumber, traderId, symbol, description, status
        case createdAt, updatedAt, completedAt, calculatedProfit
        case traderPartialSellEventCount
        case buyLegType, pairExecutionId, buyOrder, sellOrder, sellOrders
        case securityName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.objectId = try container.decode(String.self, forKey: .objectId)
        self.tradeNumber = try container.decodeIfPresent(Int.self, forKey: .tradeNumber) ?? 0
        self.traderId = try container.decodeIfPresent(String.self, forKey: .traderId) ?? ""
        self.symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ?? ""
        let desc = try container.decodeIfPresent(String.self, forKey: .description)
        let secName = try container.decodeIfPresent(String.self, forKey: .securityName)
        self.description = (desc?.isEmpty == false ? desc : secName) ?? self.symbol
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ISO8601DateFormatter().string(from: Date())
        self.updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? self.createdAt
        self.completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        self.calculatedProfit = try container.decodeIfPresent(Double.self, forKey: .calculatedProfit)
        self.traderPartialSellEventCount = try container.decodeIfPresent(Int.self, forKey: .traderPartialSellEventCount)
        self.buyLegType = try container.decodeIfPresent(String.self, forKey: .buyLegType)
        self.pairExecutionId = try container.decodeIfPresent(String.self, forKey: .pairExecutionId)
        self.buyOrder = try container.decode(ParseOrderBuy.self, forKey: .buyOrder)
        self.sellOrder = try container.decodeIfPresent(ParseOrderSell.self, forKey: .sellOrder)
        self.sellOrders = try container.decodeIfPresent([ParseOrderSell].self, forKey: .sellOrders)
    }

    func toTrade() throws -> Trade {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdDate = dateFormatter.date(from: self.createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: self.updatedAt) ?? Date()
        let completedDate = self.completedAt.flatMap { dateFormatter.date(from: $0) }
        let tradeStatus = TradeStatus(rawValue: status) ?? .pending

        let buyOrderModel = try buyOrder.toOrderBuy()
        let sellOrderModel = self.sellOrder.flatMap { try? $0.toOrderSell() }
        let sellOrdersModel = (sellOrders ?? []).compactMap { try? $0.toOrderSell() }

        return Trade(
            id: self.objectId,
            tradeNumber: self.tradeNumber,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            buyOrder: buyOrderModel,
            sellOrder: sellOrderModel,
            sellOrders: sellOrdersModel,
            status: tradeStatus,
            createdAt: createdDate,
            completedAt: completedDate,
            updatedAt: updatedDate,
            calculatedProfit: self.calculatedProfit,
            traderPartialSellEventCount: self.traderPartialSellEventCount,
            buyLegType: self.buyLegType ?? self.buyOrder.legType,
            pairExecutionId: self.pairExecutionId
        )
    }
}

struct ParseOrderBuy: Decodable {
    let id: String
    let traderId: String
    let symbol: String
    let description: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String
    let createdAt: String
    let executedAt: String?
    let confirmedAt: String?
    let updatedAt: String
    let optionDirection: String?
    let underlyingAsset: String?
    let wkn: String?
    let category: String?
    let strike: Double?
    let orderInstruction: String?
    let limitPrice: Double?
    let isMirrorPoolOrder: Bool?
    let legType: String?

    enum CodingKeys: String, CodingKey {
        case id, objectId, traderId, symbol, description, quantity, price, totalAmount, status
        case createdAt, executedAt, confirmedAt, updatedAt
        case optionDirection, underlyingAsset, wkn, category, strike, orderInstruction, limitPrice
        case isMirrorPoolOrder, legType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let objectId = try container.decodeIfPresent(String.self, forKey: .objectId)
        let decodedId = try container.decodeIfPresent(String.self, forKey: .id)
        self.id = (decodedId?.isEmpty == false ? decodedId : objectId) ?? ""
        self.traderId = try container.decodeIfPresent(String.self, forKey: .traderId) ?? ""
        self.symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ?? ""
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? self.symbol
        self.quantity = try container.decodeIfPresent(Double.self, forKey: .quantity) ?? 0
        self.price = try container.decodeIfPresent(Double.self, forKey: .price) ?? 0
        self.totalAmount = try container.decodeIfPresent(Double.self, forKey: .totalAmount) ?? 0
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "executed"
        let now = ISO8601DateFormatter().string(from: Date())
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? now
        self.updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? self.createdAt
        self.executedAt = try container.decodeIfPresent(String.self, forKey: .executedAt)
        self.confirmedAt = try container.decodeIfPresent(String.self, forKey: .confirmedAt)
        self.optionDirection = try container.decodeIfPresent(String.self, forKey: .optionDirection)
        self.underlyingAsset = try container.decodeIfPresent(String.self, forKey: .underlyingAsset)
        self.wkn = try container.decodeIfPresent(String.self, forKey: .wkn)
        self.category = try container.decodeIfPresent(String.self, forKey: .category)
        self.strike = try container.decodeIfPresent(Double.self, forKey: .strike)
        self.orderInstruction = try container.decodeIfPresent(String.self, forKey: .orderInstruction)
        self.limitPrice = try container.decodeIfPresent(Double.self, forKey: .limitPrice)
        self.isMirrorPoolOrder = try container.decodeIfPresent(Bool.self, forKey: .isMirrorPoolOrder)
        self.legType = try container.decodeIfPresent(String.self, forKey: .legType)
    }

    func toOrderBuy() throws -> OrderBuy {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdDate = dateFormatter.date(from: self.createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: self.updatedAt) ?? Date()
        let executedDate = self.executedAt.flatMap { dateFormatter.date(from: $0) }
        let confirmedDate = self.confirmedAt.flatMap { dateFormatter.date(from: $0) }
        let orderStatus = OrderBuyStatus(rawValue: status) ?? .submitted

        return OrderBuy(
            id: self.id,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            quantity: self.quantity,
            price: self.price,
            totalAmount: self.totalAmount,
            status: orderStatus,
            createdAt: createdDate,
            executedAt: executedDate,
            confirmedAt: confirmedDate,
            updatedAt: updatedDate,
            optionDirection: self.optionDirection,
            underlyingAsset: self.underlyingAsset,
            wkn: self.wkn,
            category: self.category,
            strike: self.strike,
            orderInstruction: self.orderInstruction,
            limitPrice: self.limitPrice,
            isMirrorPoolOrder: self.isMirrorPoolOrder
        )
    }
}

struct ParseOrderSell: Codable {
    let id: String
    let traderId: String
    let symbol: String
    let description: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String
    let createdAt: String
    let executedAt: String?
    let confirmedAt: String?
    let updatedAt: String
    let optionDirection: String?
    let underlyingAsset: String?
    let wkn: String?
    let category: String?
    let strike: Double?
    let orderInstruction: String?
    let limitPrice: Double?
    let originalHoldingId: String?

    func toOrderSell() throws -> OrderSell {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdDate = dateFormatter.date(from: self.createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: self.updatedAt) ?? Date()
        let executedDate = self.executedAt.flatMap { dateFormatter.date(from: $0) }
        let confirmedDate = self.confirmedAt.flatMap { dateFormatter.date(from: $0) }
        let orderStatus = OrderSellStatus(rawValue: status) ?? .submitted

        return OrderSell(
            id: self.id,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            quantity: self.quantity,
            price: self.price,
            totalAmount: self.totalAmount,
            status: orderStatus,
            createdAt: createdDate,
            executedAt: executedDate,
            confirmedAt: confirmedDate,
            updatedAt: updatedDate,
            optionDirection: self.optionDirection,
            underlyingAsset: self.underlyingAsset,
            wkn: self.wkn,
            category: self.category,
            strike: self.strike,
            orderInstruction: self.orderInstruction,
            limitPrice: self.limitPrice,
            originalHoldingId: self.originalHoldingId
        )
    }
}
