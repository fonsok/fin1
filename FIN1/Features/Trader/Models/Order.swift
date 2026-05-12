import Foundation

// MARK: - Order Model
/// **Order** = Individual buy/sell transactions with statuses and option details
///
/// Architecture Overview:
/// - **Order**: Individual buy/sell transactions with statuses and option details
/// - **Trade**: Buy + Sell order results for investor pot distribution
/// - **DepotBestand**: Holdings with split option information (final state)
///
/// Order Types:
/// - **OrderBuy**: Individual buy transactions with status progression (submitted → executed → completed)
/// - **OrderSell**: Individual sell transactions with status progression (submitted → executed → confirmed)
/// - **Order**: Generic order model for backward compatibility
struct Order: Identifiable, Codable, Sendable {
    let id: String
    let traderId: String
    let symbol: String
    let description: String
    let type: OrderType
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let createdAt: Date
    let executedAt: Date?
    let confirmedAt: Date?
    let updatedAt: Date

    // Warrant-specific fields (Optionsscheine)
    let optionDirection: String? // "CALL" or "PUT" for warrants
    let underlyingAsset: String? // "DAX"
    let wkn: String? // WKN number
    let category: String? // Product category like "Optionsschein", "Knockout", etc.
    let strike: Double? // Strike price for warrants

    // Order instruction fields
    let orderInstruction: String? // "market" or "limit"
    let limitPrice: Double? // Limit price for limit orders
    let subscriptionRatio: Double? // Units-per-share style ratio for warrants
    let denomination: Int? // Optional denomination constraint from issuer
    let isMirrorPoolOrder: Bool? // true = investor mirror-pool buy order

    // Reference to original holding for sell orders
    let originalHoldingId: String? // ID of the holding being sold

    // For backward compatibility during migration
    let status: String

    // MARK: - Initialization

    init(
        id: String,
        traderId: String,
        symbol: String,
        description: String,
        type: OrderType,
        quantity: Double,
        price: Double,
        totalAmount: Double,
        createdAt: Date,
        executedAt: Date?,
        confirmedAt: Date?,
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
        isMirrorPoolOrder: Bool? = nil,
        originalHoldingId: String? = nil,
        status: String = "submitted"
    ) {
        self.id = id
        self.traderId = traderId
        self.symbol = symbol
        self.description = description
        self.type = type
        self.quantity = quantity
        self.price = price
        self.totalAmount = totalAmount
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
        self.isMirrorPoolOrder = isMirrorPoolOrder
        self.originalHoldingId = originalHoldingId
        self.status = status
    }

    // MARK: - Computed Properties

    var isActive: Bool {
        switch type {
        case .buy:
            return buyStatus == .submitted || buyStatus == .executed
        case .sell:
            return sellStatus == .submitted || sellStatus == .executed
        }
    }

    var isCompleted: Bool {
        switch type {
        case .buy:
            return buyStatus == .completed
        case .sell:
            return sellStatus == .confirmed
        }
    }

    var buyStatus: OrderBuyStatus? {
        type == .buy ? OrderBuyStatus(rawValue: status) : nil
    }

    var sellStatus: OrderSellStatus? {
        type == .sell ? OrderSellStatus(rawValue: status) : nil
    }

    var currentStatusDisplayName: String {
        switch type {
        case .buy:
            return buyStatus?.displayName ?? "Unknown"
        case .sell:
            return sellStatus?.displayName ?? "Unknown"
        }
    }
}
