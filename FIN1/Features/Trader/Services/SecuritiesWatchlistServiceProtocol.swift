import Combine
import Foundation

// MARK: - Securities Watchlist Service Protocol
/// Defines the contract for securities watchlist operations and management
protocol SecuritiesWatchlistServiceProtocol: ObservableObject, Sendable {
    var watchlist: [SearchResult] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Watchlist Management
    func addToWatchlist(_ searchResult: SearchResult) async throws
    func removeFromWatchlist(_ wkn: String) async throws
    func clearWatchlist() async throws
    func isInWatchlist(_ wkn: String) -> Bool

    // MARK: - Watchlist Data Management
    func loadWatchlist() async throws
    func refreshWatchlist() async throws

    // MARK: - Backend Synchronization
    func syncToBackend() async
}
