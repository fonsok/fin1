import Combine
import Foundation

// MARK: - Investor Watchlist Service Protocol
/// Defines the contract for investor trader watchlist operations and management
protocol InvestorWatchlistServiceProtocol: ObservableObject, Sendable {
    var watchlist: [WatchlistTraderData] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Watchlist Management
    func addToWatchlist(_ trader: WatchlistTraderData) async throws
    func removeFromWatchlist(_ traderId: String) async throws
    func clearWatchlist() async throws
    func isInWatchlist(_ traderId: String) -> Bool

    // MARK: - Legacy Support (for existing code)
    func addToWatchlist(_ trader: WatchlistTraderData)
    func removeTraderFromWatchlist(_ trader: WatchlistTraderData)
    func isInWatchlist(_ trader: WatchlistTraderData) -> Bool

    // MARK: - Backend Synchronization
    func syncToBackend() async
}
