import Combine
import Foundation

// MARK: - Legacy Trading State Store
/// Legacy implementation for backward compatibility with existing services
final class LegacyTradingStateStore: TradingStateLifecycleProtocol, @unchecked Sendable {
    // MARK: - State Publishers
    var activeOrdersPublisher: AnyPublisher<[Order], Never> {
        self.orderManagementService.activeOrdersPublisher
    }

    var completedTradesPublisher: AnyPublisher<[Trade], Never> {
        self.tradeLifecycleService.completedTradesPublisher
    }

    var watchlistPublisher: AnyPublisher<[SearchResult], Never> {
        // Return empty publisher for now
        Just([]).eraseToAnyPublisher()
    }

    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        // Return false for now
        Just(false).eraseToAnyPublisher()
    }

    var errorMessagePublisher: AnyPublisher<String?, Never> {
        // Return nil for now
        Just(nil).eraseToAnyPublisher()
    }

    // MARK: - Dependencies
    private let orderManagementService: any OrderManagementServiceProtocol
    private let tradeLifecycleService: any TradeLifecycleServiceProtocol
    private let securitiesWatchlistService: any SecuritiesWatchlistServiceProtocol
    private let orderStatusSimulationService: any OrderStatusSimulationServiceProtocol

    // MARK: - Initialization
    init(
        orderManagementService: any OrderManagementServiceProtocol,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        securitiesWatchlistService: any SecuritiesWatchlistServiceProtocol,
        orderStatusSimulationService: any OrderStatusSimulationServiceProtocol
    ) {
        self.orderManagementService = orderManagementService
        self.tradeLifecycleService = tradeLifecycleService
        self.securitiesWatchlistService = securitiesWatchlistService
        self.orderStatusSimulationService = orderStatusSimulationService
    }

    // MARK: - State Management
    func start() {
        // No-op for now
    }

    func stop() {
        // No-op for now
    }

    func reset() {
        // No-op for now
    }

    // MARK: - Data Loading
    func loadAllTradingData() async throws {
        // Load data from all services
        try await self.orderManagementService.loadActiveOrders()
        try await self.tradeLifecycleService.loadCompletedTrades()
    }

    func refreshTradingData() async throws {
        // Refresh data from all services
        try await self.orderManagementService.refreshActiveOrders()
        try await self.tradeLifecycleService.refreshCompletedTrades()
    }
}
