import Foundation
import Combine
@testable import FIN1

final class MockTradeLifecycleService: TradeLifecycleServiceProtocol {
    @Published var completedTrades: [Trade]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    var completedTradesPublisher: AnyPublisher<[Trade], Never> {
        $completedTrades.eraseToAnyPublisher()
    }

    init(completedTrades: [Trade] = []) {
        self.completedTrades = completedTrades
    }

    // MARK: - Protocol requirements (unused stubs)
    func createNewTrade(buyOrder: OrderBuy) async throws -> Trade {
        fatalError("Not implemented in mock")
    }

    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws {
        fatalError("Not implemented in mock")
    }

    func addPartialSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws {
        fatalError("Not implemented in mock")
    }

    func cancelTrade(_ tradeId: String) async throws {
        fatalError("Not implemented in mock")
    }

    func completeTrade(_ tradeId: String) async throws {
        fatalError("Not implemented in mock")
    }

    func loadCompletedTrades() async throws {
        // no-op
    }

    func refreshCompletedTrades() async throws {
        // no-op
    }
}
