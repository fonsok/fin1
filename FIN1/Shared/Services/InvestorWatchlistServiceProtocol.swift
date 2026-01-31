import Foundation
import Combine

// MARK: - Investor Watchlist Service Protocol
/// Defines the contract for investor trader watchlist operations and management
protocol InvestorWatchlistServiceProtocol: ObservableObject {
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

}
