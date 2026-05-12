import Foundation

// MARK: - Holdings Conversion Service Protocol

/// Protocol for centralized holdings creation from trades
/// **SINGLE SOURCE OF TRUTH** for converting Trade → DepotHolding
/// This eliminates DRY violations where the same logic was duplicated in 4+ places
protocol HoldingsConversionServiceProtocol: Sendable {
    /// Creates a DepotHolding from a trade, properly accounting for partial sales
    /// - Parameters:
    ///   - trade: The trade to convert
    ///   - position: Position number in the depot
    ///   - ongoingOrders: Optional ongoing orders to check for executed sell orders not yet in trade
    /// - Returns: A DepotHolding representing the current state of the trade's holdings
    func createHolding(from trade: Trade, position: Int, ongoingOrders: [Order]) -> DepotHolding

    /// Creates holdings from multiple trades
    /// - Parameters:
    ///   - trades: Array of trades to convert
    ///   - ongoingOrders: Optional ongoing orders
    /// - Returns: Array of DepotHolding with remaining quantity > 0
    func createHoldings(from trades: [Trade], ongoingOrders: [Order]) -> [DepotHolding]
}

// MARK: - Holdings Conversion Service Implementation

/// **SINGLE SOURCE OF TRUTH** for Trade → DepotHolding conversion
///
/// Previously this logic was duplicated in:
/// - TraderDepotViewModel.createHoldingFromTrade
/// - TradeMatchingService.createHoldingFromTrade
/// - TradingStateStore.createHoldingFromTrade
/// - DashboardStatsSection.createHoldingFromTrade
///
/// All these should now use this centralized service.
final class HoldingsConversionService: HoldingsConversionServiceProtocol, @unchecked Sendable {

    // MARK: - Singleton

    static let shared = HoldingsConversionService()

    private init() {}

    // MARK: - Public Methods

    func createHolding(from trade: Trade, position: Int, ongoingOrders: [Order] = []) -> DepotHolding {
        // Start with base holding from buy order
        var holding = DepotHolding.from(completedOrder: trade.buyOrder, position: position)

        // Apply partial sales from sellOrders array (primary source of truth)
        if !trade.sellOrders.isEmpty {
            let totalSoldQuantity = trade.sellOrders.reduce(0) { $0 + Int($1.quantity) }
            holding = holding.withPartialSale(soldQuantity: totalSoldQuantity)
        }

        // Legacy: handle single sellOrder if present AND not already in sellOrders array
        // This prevents double-counting when Trade.with(sellOrder:) was used,
        // which adds the order to BOTH sellOrder and sellOrders fields
        if let sellOrder = trade.sellOrder {
            let alreadyInArray = trade.sellOrders.contains { $0.id == sellOrder.id }
            if !alreadyInArray {
                let soldQuantity = Int(sellOrder.quantity)
                holding = holding.withPartialSale(soldQuantity: soldQuantity)
            }
        }

        // Apply executed ongoing orders that haven't been added to the trade yet
        let executedOngoingOrders = findExecutedOngoingOrders(for: holding, in: ongoingOrders)
        if !executedOngoingOrders.isEmpty {
            let executedQuantity = executedOngoingOrders.reduce(0) { $0 + Int($1.quantity) }
            holding = holding.withPartialSale(soldQuantity: executedQuantity)
        }

        return holding
    }

    func createHoldings(from trades: [Trade], ongoingOrders: [Order] = []) -> [DepotHolding] {
        var positionCounter = 1
        let allHoldings = trades.map { trade -> DepotHolding in
            defer { positionCounter += 1 }
            return createHolding(from: trade, position: positionCounter, ongoingOrders: ongoingOrders)
        }

        // Filter to only holdings with remaining quantity
        return allHoldings.filter { $0.remainingQuantity > 0 }
    }

    // MARK: - Private Methods

    /// Finds ongoing sell orders that are executed/confirmed but not yet recorded in the trade
    private func findExecutedOngoingOrders(for holding: DepotHolding, in ongoingOrders: [Order]) -> [Order] {
        return ongoingOrders.filter { order in
            guard order.type == .sell else { return false }

            // Check if this order belongs to this holding
            let holdingOrderId = holding.orderId
            let holdingWkn = holding.wkn
            let belongsToHolding = order.originalHoldingId == holdingOrderId ||
                                   order.originalHoldingId == holdingWkn ||
                                   order.symbol == holdingWkn

            // Check if order is in executed or confirmed status
            let isExecutedOrConfirmed = order.sellStatus == .executed || order.sellStatus == .confirmed

            return belongsToHolding && isExecutedOrConfirmed
        }
    }
}











