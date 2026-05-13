import Combine
import Foundation

// MARK: - Trade Lifecycle Service Protocol
/// Defines the contract for trade creation, completion, and management
protocol TradeLifecycleServiceProtocol: ObservableObject, Sendable {
    var completedTrades: [Trade] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // Publishers for observation (MVVM-friendly)
    var completedTradesPublisher: AnyPublisher<[Trade], Never> { get }

    // MARK: - Trade Management
    func createNewTrade(buyOrder: OrderBuy) async throws -> Trade
    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws
    func addPartialSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws
    func cancelTrade(_ tradeId: String) async throws
    func completeTrade(_ tradeId: String) async throws

    // MARK: - Trade Data Management
    func loadCompletedTrades() async throws
    func refreshCompletedTrades() async throws
}
