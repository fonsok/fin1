import Foundation

// MARK: - Trade Matching Service Protocol
/// Defines the contract for trade matching operations
/// Handles complex business logic for matching sell orders with existing trades
protocol TradeMatchingServiceProtocol: Sendable {
    /// Finds and updates a trade with a completed sell order
    /// - Parameters:
    ///   - sellOrder: The completed sell order to match
    ///   - trades: The list of completed trades to search through
    ///   - tradeLifecycleService: Service to update the trade
    /// - Returns: The updated trade if found, nil otherwise
    func findAndUpdateTradeWithSellOrder(
        sellOrder: OrderSell,
        trades: [Trade],
        tradeLifecycleService: any TradeLifecycleServiceProtocol
    ) async -> Trade?

    /// Converts trades to holdings representation
    /// - Parameter trades: The trades to convert
    /// - Returns: Array of holdings
    func getHoldingsFromTrades(_ trades: [Trade]) -> [DepotHolding]

    /// Adds a partial sell order to an existing trade
    /// - Parameters:
    ///   - tradeId: The ID of the trade to update
    ///   - sellOrder: The partial sell order to add
    ///   - trades: The list of trades to search through
    ///   - tradeLifecycleService: Service to update the trade
    /// - Returns: The updated trade if successful, nil otherwise
    func addPartialSellOrderToTrade(
        tradeId: String,
        sellOrder: OrderSell,
        trades: [Trade],
        tradeLifecycleService: any TradeLifecycleServiceProtocol
    ) async -> Trade?
}
