import Foundation
import SwiftUI

// MARK: - Trade Status

enum TradeStatus: String, CaseIterable, Codable, Sendable {
    case pending         // Only buy order exists
    case active           // Buy order confirmed, sell order exists
    case completed     // Both orders completed
    case cancelled     // Trade cancelled

    var displayName: String {
        switch self {
        case .pending: return "Ausstehend"
        case .active: return "Aktiv"
        case .completed: return "Abgeschlossen"
        case .cancelled: return "Storniert"
        }
    }

    var color: Color {
        switch self {
        case .pending: return AppTheme.accentOrange
        case .active: return AppTheme.accentLightBlue
        case .completed: return AppTheme.accentGreen
        case .cancelled: return AppTheme.accentRed
        }
    }
}

// MARK: - Trade Model
/// **Trade** = Buy + Sell order results for investor pool distribution
///
/// Architecture Overview:
/// - **Trade**: Represents a complete trading cycle (buy + sell) for investor pool distribution
/// - **Order**: Individual buy/sell transactions with statuses and option details
/// - **DepotBestand**: Holdings with split option information (final state after trade completion)
///
/// Trade Lifecycle:
/// 1. Trade created from buy order (status: pending)
/// 2. Sell order added (status: active)
/// 3. Both orders completed (status: completed)
/// 4. Trade moved to DepotBestand (holdings)
struct Trade: Identifiable, Codable, Sendable {
    let id: String
    let tradeNumber: Int // User-friendly sequential number (001, 002, 003...)
    let traderId: String
    let symbol: String
    let description: String
    let buyOrder: OrderBuy
    let sellOrder: OrderSell? // Legacy: single sell order (for backward compatibility)
    let sellOrders: [OrderSell] // New: multiple partial sell orders
    let status: TradeStatus
    let createdAt: Date
    let completedAt: Date?
    let updatedAt: Date

    // Pre-calculated profit from invoices (single source of truth)
    let calculatedProfit: Double?

    // MARK: - Codable Support
    enum CodingKeys: String, CodingKey {
        case id, tradeNumber, traderId, symbol, description, buyOrder, sellOrder, sellOrders, status, createdAt, completedAt, updatedAt, calculatedProfit
    }

    init(id: String, tradeNumber: Int, traderId: String, symbol: String, description: String, buyOrder: OrderBuy, sellOrder: OrderSell?, sellOrders: [OrderSell], status: TradeStatus, createdAt: Date, completedAt: Date?, updatedAt: Date, calculatedProfit: Double? = nil) {
        self.id = id
        self.tradeNumber = tradeNumber
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        tradeNumber = try container.decodeIfPresent(Int.self, forKey: .tradeNumber) ?? 0 // Default to 0 for backward compatibility
        traderId = try container.decode(String.self, forKey: .traderId)
        symbol = try container.decode(String.self, forKey: .symbol)
        description = try container.decode(String.self, forKey: .description)
        buyOrder = try container.decode(OrderBuy.self, forKey: .buyOrder)
        sellOrder = try container.decodeIfPresent(OrderSell.self, forKey: .sellOrder)
        sellOrders = try container.decodeIfPresent([OrderSell].self, forKey: .sellOrders) ?? [] // Default to empty array for backward compatibility
        status = try container.decode(TradeStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        calculatedProfit = try container.decodeIfPresent(Double.self, forKey: .calculatedProfit)
    }

    // Options-specific fields (derived from buyOrder)
    var optionDirection: String? { buyOrder.optionDirection }
    var underlyingAsset: String? { buyOrder.underlyingAsset }
    var wkn: String? { buyOrder.wkn }

    // User-friendly trade number display
    var formattedTradeNumber: String {
        return String(format: "%03d", tradeNumber)
    }

    // Calculated properties
    var isActive: Bool {
        // Trade is active if it has remaining quantity (not fully sold)
        // Use !isFullySold for consistency to avoid floating point issues
        return !isFullySold
    }

    var isCompleted: Bool {
        // Trade is completed only when all securities are sold (remainingQuantity ≈ 0)
        // and the relevant sell order is completed
        // Use isFullySold to avoid floating point precision issues with == 0
        return isFullySold && hasCompletedSellOrders
    }

    private var hasCompletedSellOrders: Bool {
        // Check if we have any sell orders and they are completed
        let hasSellOrders = !sellOrders.isEmpty || sellOrder != nil
        guard hasSellOrders else { return false }

        // Check if all sell orders are completed
        let allSellOrdersCompleted = sellOrders.allSatisfy { $0.status == .confirmed || $0.status == .completed }
        let legacySellOrderCompleted = sellOrder?.status == .confirmed || sellOrder?.status == .completed

        return allSellOrdersCompleted && (sellOrder == nil || legacySellOrderCompleted)
    }

    var totalQuantity: Double {
        buyOrder.quantity
    }

    var entryPrice: Double {
        buyOrder.price
    }

    var exitPrice: Double? {
        // Use the most recent sell order price, or legacy sellOrder for backward compatibility
        if let latestSellOrder = sellOrders.last {
            return latestSellOrder.price
        }
        return sellOrder?.price
    }

    // MARK: - Partial Sales Support
    var totalSoldQuantity: Double {
        return sellOrders.reduce(0) { $0 + $1.quantity }
    }

    var remainingQuantity: Double {
        return buyOrder.quantity - totalSoldQuantity
    }

    var isPartiallySold: Bool {
        return totalSoldQuantity > 0 && totalSoldQuantity < buyOrder.quantity
    }

    var isFullySold: Bool {
        return totalSoldQuantity >= buyOrder.quantity
    }

    var currentPnL: Double? {
        // Use pre-calculated profit if available (single source of truth)
        if let calculatedProfit = calculatedProfit {
            return calculatedProfit
        }

        // Fallback to calculation for backward compatibility
        let executedSellOrders = sellOrders.filter { $0.status == .confirmed || $0.status == .completed }
        guard !executedSellOrders.isEmpty else { return nil }

        // Use centralized profit calculation service to avoid DRY violations
        return ProfitCalculationService.calculateGrossProfitFromOrders(for: self)
    }

    var finalPnL: Double? {
        guard isCompleted else { return nil }
        return currentPnL
    }

    // MARK: - Display Properties (Single Source of Truth)

    /// **SINGLE SOURCE OF TRUTH for profit display**
    /// Use this property everywhere profit needs to be displayed to ensure consistency.
    /// Fallback chain: calculatedProfit (invoice-verified) → order-based calculation → 0
    ///
    /// This ensures Profit value and ROI percentage always use the same source.
    var displayProfit: Double {
        // 1. Pre-calculated profit (highest priority - invoice-verified, stored on trade completion)
        if let calculated = calculatedProfit {
            return calculated
        }
        // 2. Order-based calculation (always available for trades with executed sell orders)
        if let pnl = currentPnL {
            return pnl
        }
        // 3. Zero fallback (no sell orders yet)
        return 0.0
    }

    /// **SINGLE SOURCE OF TRUTH for ROI display**
    /// Use this property everywhere ROI needs to be displayed to ensure consistency.
    var displayROI: Double {
        return roi ?? 0.0
    }

    /// Return percentage (ROI) for this trade
    /// Calculated as: (profit / invested amount) * 100
    /// Uses invoice-based profit calculation for consistency with investor return calculations
    /// **ACCOUNTING PRINCIPLE**: Denominator includes fees because that's what was actually invested
    var roi: Double? {
        guard let pnl = currentPnL, totalSoldQuantity > 0 else { return nil }
        // ✅ Uses invoice-based profit calculation (calculateTaxableProfit via currentPnL)
        // This matches investor return calculation method for consistency
        // Both trader return percentage and investor return percentage use the same calculation source

        // Calculate total buy cost including fees (accounting principle: what was actually invested)
        let buySecuritiesValue = buyOrder.price * totalSoldQuantity
        let buyFees = FeeCalculationService.calculateTotalFees(for: buySecuritiesValue)
        let totalBuyCost = buySecuritiesValue + buyFees

        // Use shared utility function for consistent calculation (single source of truth)
        return ProfitCalculationService.calculateReturnPercentage(
            grossProfit: pnl,
            investedAmount: totalBuyCost
        )
    }

    var duration: TimeInterval? {
        guard let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(buyOrder.createdAt)
    }

    // Computed status based on order statuses and remaining quantity
    var computedStatus: TradeStatus {
        // Check for cancellation
        if buyOrder.status == .cancelled {
            return .cancelled
        }

        // Check if any sell orders are cancelled
        if sellOrders.contains(where: { $0.status == .cancelled }) {
            return .cancelled
        }

        // Legacy: check single sellOrder for cancellation
        if let sellOrder = sellOrder, sellOrder.status == .cancelled {
            return .cancelled
        }

        // Trade lifecycle based on remaining quantity
        if buyOrder.status == .completed {
            // Check if all securities are sold (use isFullySold to avoid floating point issues)
            if isFullySold {
                // All securities sold - check if sell orders are completed
                if hasCompletedSellOrders {
                    return .completed
                } else {
                    return .active // Sell orders exist but not completed yet
                }
            } else {
                // Still have remaining securities - trade is active
                return .active
            }
        }

        return .pending
    }
}

// MARK: - Trade Result

struct TradeResult: Identifiable, Codable, Sendable {
    let id: String
    let tradeId: String
    let traderId: String
    let profitLoss: Double
    let fees: Double
    let taxes: Double
    let performanceFee: Double
    let netProfitLoss: Double
    let createdAt: Date

    var isProfitable: Bool {
        netProfitLoss > 0
    }
}

// MARK: - Trade Extensions

extension Trade {
    /// Creates a trade from a buy order (pending state)
    static func from(buyOrder: OrderBuy, tradeNumber: Int) -> Trade {
        Trade(
            id: UUID().uuidString,
            tradeNumber: tradeNumber,
            traderId: buyOrder.traderId,
            symbol: buyOrder.symbol,
            description: buyOrder.description,
            buyOrder: buyOrder,
            sellOrder: nil, // Legacy support
            sellOrders: [], // Initialize empty array for partial sales
            status: .pending,
            createdAt: buyOrder.createdAt,
            completedAt: nil,
            updatedAt: buyOrder.updatedAt
        )
    }

    /// Adds a sell order to an existing trade (legacy method for backward compatibility)
    func with(sellOrder: OrderSell) -> Trade {
        Trade(
            id: self.id,
            tradeNumber: self.tradeNumber,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            buyOrder: self.buyOrder,
            sellOrder: sellOrder, // Legacy support
            sellOrders: self.sellOrders + [sellOrder], // Add to partial sales array
            status: .active,
            createdAt: self.createdAt,
            completedAt: nil,
            updatedAt: sellOrder.updatedAt
        )
    }

    /// Adds a partial sell order to an existing trade
    func withPartialSellOrder(_ sellOrder: OrderSell) -> Trade {
        Trade(
            id: self.id,
            tradeNumber: self.tradeNumber,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            buyOrder: self.buyOrder,
            sellOrder: self.sellOrder, // Keep legacy sellOrder unchanged
            sellOrders: self.sellOrders + [sellOrder], // Add new partial sell order
            status: .active,
            createdAt: self.createdAt,
            completedAt: nil,
            updatedAt: sellOrder.updatedAt
        )
    }

    /// Updates the trade status based on current order statuses
    func updateStatus() -> Trade {
        let newStatus = self.computedStatus
        let isCompleted = newStatus == .completed

        return Trade(
            id: self.id,
            tradeNumber: self.tradeNumber,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            buyOrder: self.buyOrder,
            sellOrder: self.sellOrder, // Keep legacy sellOrder
            sellOrders: self.sellOrders, // Keep all partial sell orders
            status: newStatus,
            createdAt: self.createdAt,
            completedAt: isCompleted ? Date() : nil,
            updatedAt: Date(),
            calculatedProfit: self.calculatedProfit // Keep existing calculated profit
        )
    }

    /// Updates the trade with a pre-calculated profit value (called by services)
    func withCalculatedProfit(_ profit: Double) -> Trade {
        return Trade(
            id: self.id,
            tradeNumber: self.tradeNumber,
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
