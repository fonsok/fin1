import Foundation
import Combine

// MARK: - Investor Watchlist Service Implementation
/// Handles investor trader watchlist operations and management
/// Based on the working trader securities watchlist pattern
final class InvestorWatchlistService: InvestorWatchlistServiceProtocol, ServiceLifecycle {
    static let shared = InvestorWatchlistService()

    @Published var watchlist: [WatchlistTraderData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        // Start with empty watchlist - no mock data
    }

    // MARK: - ServiceLifecycle
    func start() {
        // No initial loading needed
    }

    func stop() {
        // Clean up any ongoing operations
    }

    func reset() {
        watchlist.removeAll()
        errorMessage = nil
    }

    // MARK: - Watchlist Management

    func addToWatchlist(_ trader: WatchlistTraderData) async throws {
        await MainActor.run {
            // Check if already in watchlist
            if !watchlist.contains(where: { $0.id == trader.id }) {
                watchlist.append(trader)
                print("✅ Added to investor watchlist: \(trader.name) (id: \(trader.id))")
                // Post notification to trigger UI updates
                NotificationCenter.default.post(name: .init("WatchlistUpdated"), object: nil)
            } else {
                print("⚠️ Already in investor watchlist: \(trader.name)")
            }
        }
    }

    func removeFromWatchlist(_ traderId: String) async throws {
        await MainActor.run {
            print("🔍 removeFromWatchlist called with ID: \(traderId)")
            print("🔍 Current watchlist count before removal: \(watchlist.count)")
            print("🔍 Current watchlist IDs: \(watchlist.map { $0.id })")

            let initialCount = watchlist.count
            watchlist.removeAll { $0.id == traderId }
            let finalCount = watchlist.count

            print("🔍 Watchlist count after removal: \(finalCount)")
            print("🔍 Items removed: \(initialCount - finalCount)")
            print("❌ Removed from investor watchlist: \(traderId)")
            // Post notification to trigger UI updates
            NotificationCenter.default.post(name: .init("WatchlistUpdated"), object: nil)
        }
    }

    func clearWatchlist() async throws {
        await MainActor.run {
            watchlist.removeAll()
            print("🗑️ Cleared investor watchlist")
            // Post notification to trigger UI updates
            NotificationCenter.default.post(name: .init("WatchlistUpdated"), object: nil)
            print("🔔 [Service] posted WatchlistUpdated after clear, count=\(watchlist.count)")
        }
    }

    func isInWatchlist(_ traderId: String) -> Bool {
        return watchlist.contains { $0.id == traderId }
    }

    // MARK: - Legacy Support (for existing code)

    func addToWatchlist(_ trader: WatchlistTraderData) {
        Task {
            try? await addToWatchlist(trader)
        }
    }

    func removeTraderFromWatchlist(_ trader: WatchlistTraderData) {
        Task {
            try? await removeFromWatchlist(trader.id)
        }
    }

    func isInWatchlist(_ trader: WatchlistTraderData) -> Bool {
        return isInWatchlist(trader.id)
    }

}
