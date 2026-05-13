import Foundation
import SwiftUI

// MARK: - Simplified Order Architecture
/// Single Order model that handles both buy and sell orders
/// Replaces Order, OrderBuy, OrderSell with one clean model

// MARK: - New Order Types
enum NewOrderType: String, CaseIterable, Codable {
    case buy
    case sell

    var displayName: String {
        switch self {
        case .buy: return "Buy"
        case .sell: return "Sell"
        }
    }

    var systemImage: String {
        switch self {
        case .buy: return "arrow.up.circle.fill"
        case .sell: return "arrow.down.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .buy: return AppTheme.accentGreen
        case .sell: return AppTheme.accentRed
        }
    }
}

// MARK: - New Order Status
enum NewOrderStatus: String, CaseIterable, Codable {
    case submitted     // Status 1: Order placed
    case suspended     // Status 2: Trading suspended
    case executed      // Status 3: Order executed
    case confirmed     // Status 4: Order confirmed
    case completed     // Status 5: Order completed (final status)
    case cancelled

    var displayName: String {
        switch self {
        case .submitted: return "Submitted"
        case .suspended: return "Trading Suspended"
        case .executed: return "Executed"
        case .confirmed: return "Confirmed"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var code: Int {
        switch self {
        case .submitted: return 1
        case .suspended: return 2
        case .executed: return 3
        case .confirmed: return 4
        case .completed: return 5
        case .cancelled: return 0
        }
    }

    var color: Color {
        switch self {
        case .submitted: return AppTheme.accentOrange
        case .suspended: return AppTheme.accentOrange
        case .executed: return AppTheme.accentLightBlue
        case .confirmed: return AppTheme.accentLightBlue
        case .completed: return AppTheme.accentGreen
        case .cancelled: return AppTheme.accentRed
        }
    }
}

// MARK: - New Order Model
struct NewOrder: Identifiable, Codable {
    let id: String
    let traderId: String
    let symbol: String
    let description: String
    let type: NewOrderType
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: NewOrderStatus
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

    // Reference to original holding for sell orders
    let originalHoldingId: String? // ID of the holding being sold

    // MARK: - Computed Properties
    var isActive: Bool {
        self.status == .submitted || self.status == .executed
    }

    var isCompleted: Bool {
        self.status == .completed
    }

    var statusCode: Int {
        self.status.code
    }

    var statusDisplayName: String {
        self.status.displayName
    }

    var statusColor: Color {
        self.status.color
    }

    // MARK: - Initializers
    init(
        id: String = UUID().uuidString,
        traderId: String = "unknown_trader", // Should be provided by caller with actual user ID
        symbol: String,
        description: String,
        type: NewOrderType,
        quantity: Double,
        price: Double,
        optionDirection: String? = nil,
        underlyingAsset: String? = nil,
        wkn: String? = nil,
        category: String? = nil,
        strike: Double? = nil,
        orderInstruction: String? = "market",
        limitPrice: Double? = nil,
        originalHoldingId: String? = nil,
        status: NewOrderStatus = .submitted
    ) {
        self.id = id
        self.traderId = traderId
        self.symbol = symbol
        self.description = description
        self.type = type
        self.quantity = quantity
        self.price = price
        self.totalAmount = quantity * price
        self.status = status
        self.createdAt = Date()
        self.executedAt = nil
        self.confirmedAt = nil
        self.updatedAt = Date()
        self.optionDirection = optionDirection
        self.underlyingAsset = underlyingAsset
        self.wkn = wkn
        self.category = category
        self.strike = strike
        self.orderInstruction = orderInstruction
        self.limitPrice = limitPrice
        self.originalHoldingId = originalHoldingId
    }

    // MARK: - Status Update
    func withStatus(_ newStatus: NewOrderStatus) -> NewOrder {
        NewOrder(
            id: self.id,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            type: self.type,
            quantity: self.quantity,
            price: self.price,
            optionDirection: self.optionDirection,
            underlyingAsset: self.underlyingAsset,
            wkn: self.wkn,
            category: self.category,
            strike: self.strike,
            orderInstruction: self.orderInstruction,
            limitPrice: self.limitPrice,
            originalHoldingId: self.originalHoldingId,
            status: newStatus
        )
    }
}

// MARK: - New Order Request Models
struct NewBuyOrderRequest {
    let symbol: String
    let quantity: Int
    let price: Double
    let optionDirection: String?
    let description: String?
    let orderInstruction: String?
    let limitPrice: Double?
    let strike: Double?
}

struct NewSellOrderRequest {
    let symbol: String
    let quantity: Int
    let price: Double
    let optionDirection: String?
    let description: String?
    let orderInstruction: String?
    let limitPrice: Double?
    let strike: Double?
    let originalHoldingId: String?
}

// MARK: - Notification Names
extension Notification.Name {
    static let orderCompleted = Notification.Name("orderCompleted")
    static let newOrderStatusUpdated = Notification.Name("newOrderStatusUpdated")
}
