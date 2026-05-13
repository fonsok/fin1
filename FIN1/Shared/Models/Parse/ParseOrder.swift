import Foundation

// Import OrderType enum
// Note: OrderType is defined in FIN1/Features/Trader/Models/OrderType.swift

// MARK: - Parse Order Model
/// Represents an Order as stored in Parse Server
/// Supports both OrderBuy and OrderSell types
struct ParseOrder: Codable {
    let objectId: String? // Parse Server generated ID
    let traderId: String
    let symbol: String
    let description: String
    let type: String // "buy" or "sell"
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String // OrderBuyStatus or OrderSellStatus rawValue
    let createdAt: Date
    let executedAt: Date?
    let confirmedAt: Date?
    let updatedAt: Date
    
    // Warrant-specific fields
    let optionDirection: String? // "CALL" or "PUT"
    let underlyingAsset: String? // "DAX"
    let wkn: String?
    let category: String?
    let strike: Double?
    
    // Order instruction fields
    let orderInstruction: String? // "market" or "limit"
    let limitPrice: Double?
    let subscriptionRatio: Double?
    let denomination: Int?
    
    // Reference to original holding for sell orders
    let originalHoldingId: String?
    
    // MARK: - Initialization
    
    init(
        objectId: String? = nil,
        traderId: String,
        symbol: String,
        description: String,
        type: String,
        quantity: Double,
        price: Double,
        totalAmount: Double,
        status: String,
        createdAt: Date,
        executedAt: Date? = nil,
        confirmedAt: Date? = nil,
        updatedAt: Date,
        optionDirection: String? = nil,
        underlyingAsset: String? = nil,
        wkn: String? = nil,
        category: String? = nil,
        strike: Double? = nil,
        orderInstruction: String? = nil,
        limitPrice: Double? = nil,
        subscriptionRatio: Double? = nil,
        denomination: Int? = nil,
        originalHoldingId: String? = nil
    ) {
        self.objectId = objectId
        self.traderId = traderId
        self.symbol = symbol
        self.description = description
        self.type = type
        self.quantity = quantity
        self.price = price
        self.totalAmount = totalAmount
        self.status = status
        self.createdAt = createdAt
        self.executedAt = executedAt
        self.confirmedAt = confirmedAt
        self.updatedAt = updatedAt
        self.optionDirection = optionDirection
        self.underlyingAsset = underlyingAsset
        self.wkn = wkn
        self.category = category
        self.strike = strike
        self.orderInstruction = orderInstruction
        self.limitPrice = limitPrice
        self.subscriptionRatio = subscriptionRatio
        self.denomination = denomination
        self.originalHoldingId = originalHoldingId
    }
    
    // MARK: - Conversion to Order
    
    func toOrder() -> Order {
        let orderType: OrderType = self.type == "buy" ? .buy : .sell
        
        return Order(
            id: self.objectId ?? UUID().uuidString,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            type: orderType,
            quantity: self.quantity,
            price: self.price,
            totalAmount: self.totalAmount,
            createdAt: self.createdAt,
            executedAt: self.executedAt,
            confirmedAt: self.confirmedAt,
            updatedAt: self.updatedAt,
            optionDirection: self.optionDirection,
            underlyingAsset: self.underlyingAsset,
            wkn: self.wkn,
            category: self.category,
            strike: self.strike,
            orderInstruction: self.orderInstruction,
            limitPrice: self.limitPrice,
            subscriptionRatio: self.subscriptionRatio,
            denomination: self.denomination,
            originalHoldingId: self.originalHoldingId,
            status: self.status
        )
    }
    
    // MARK: - Conversion from Order
    
    static func from(_ order: Order) -> ParseOrder {
        return ParseOrder(
            objectId: nil, // Will be set by Parse Server
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            type: order.type.rawValue,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: order.status,
            createdAt: order.createdAt,
            executedAt: order.executedAt,
            confirmedAt: order.confirmedAt,
            updatedAt: order.updatedAt,
            optionDirection: order.optionDirection,
            underlyingAsset: order.underlyingAsset,
            wkn: order.wkn,
            category: order.category,
            strike: order.strike,
            orderInstruction: order.orderInstruction,
            limitPrice: order.limitPrice,
            subscriptionRatio: order.subscriptionRatio,
            denomination: order.denomination,
            originalHoldingId: order.originalHoldingId
        )
    }
}
