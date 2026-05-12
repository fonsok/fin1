import Foundation

// MARK: - Trade Lifecycle Coordinator Protocol
/// Defines the contract for trade lifecycle management
/// Handles trade creation, completion, and lifecycle operations
@MainActor
protocol TradeLifecycleCoordinatorProtocol: Sendable {
    // MARK: - Trade Management
    func createNewTrade(buyOrder: OrderBuy) async throws -> Trade
    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws
    func cancelTrade(_ tradeId: String) async throws
    func completeTrade(_ tradeId: String) async throws
}
