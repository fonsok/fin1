import Combine
import Foundation

// MARK: - Trading State Store Lifecycle Protocol
/// Defines the contract for trading state management lifecycle
/// Handles state aggregation, publishing, and lifecycle management
protocol TradingStateStoreLifecycleProtocol {
    // MARK: - State Publishers
    var activeOrdersPublisher: AnyPublisher<[Order], Never> { get }
    var completedTradesPublisher: AnyPublisher<[Trade], Never> { get }
    var watchlistPublisher: AnyPublisher<[SearchResult], Never> { get }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }
    var errorMessagePublisher: AnyPublisher<String?, Never> { get }

    // MARK: - State Management
    func start()
    func stop()
    func reset()

    // MARK: - Data Loading
    func loadAllTradingData() async throws
    func refreshTradingData() async throws
}
