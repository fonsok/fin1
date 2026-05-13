import Foundation

// MARK: - Trade Lifecycle Coordinator Implementation
/// Handles trade lifecycle management and business logic
/// Focused on trade creation, completion, and lifecycle operations
@MainActor
final class TradeLifecycleCoordinator: TradeLifecycleCoordinatorProtocol {

    // MARK: - Dependencies
    private let tradeLifecycleService: any TradeLifecycleServiceProtocol

    // MARK: - Initialization
    init(tradeLifecycleService: any TradeLifecycleServiceProtocol) {
        self.tradeLifecycleService = tradeLifecycleService
    }

    // MARK: - Trade Management

    func createNewTrade(buyOrder: OrderBuy) async throws -> Trade {
        return try await self.tradeLifecycleService.createNewTrade(buyOrder: buyOrder)
    }

    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws {
        try await self.tradeLifecycleService.addSellOrderToTrade(tradeId, sellOrder: sellOrder)
    }

    func cancelTrade(_ tradeId: String) async throws {
        try await self.tradeLifecycleService.cancelTrade(tradeId)
    }

    func completeTrade(_ tradeId: String) async throws {
        try await self.tradeLifecycleService.completeTrade(tradeId)
    }
}
