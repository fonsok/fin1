import Foundation
import Combine

// MARK: - Investor Watchlist Service Implementation
/// Handles investor trader watchlist operations and management
/// Based on the working trader securities watchlist pattern
final class InvestorWatchlistService: InvestorWatchlistServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    static let shared = InvestorWatchlistService()

    @Published var watchlist: [WatchlistTraderData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Backend synchronization dependencies (optional)
    private var investorWatchlistAPIService: InvestorWatchlistAPIServiceProtocol?
    private var userService: (any UserServiceProtocol)?

    init(
        investorWatchlistAPIService: InvestorWatchlistAPIServiceProtocol? = nil,
        userService: (any UserServiceProtocol)? = nil
    ) {
        self.investorWatchlistAPIService = investorWatchlistAPIService
        self.userService = userService
        // Start with empty watchlist - no mock data
    }

    /// Configure backend dependencies (called after initialization)
    func configure(investorWatchlistAPIService: InvestorWatchlistAPIServiceProtocol, userService: (any UserServiceProtocol)) {
        self.investorWatchlistAPIService = investorWatchlistAPIService
        self.userService = userService
    }

    private var currentInvestorId: String? {
        userService?.currentUser?.id
    }

    // MARK: - ServiceLifecycle
    func start() {
        // Load watchlist from backend
        Task {
            await loadFromBackend()
        }
    }

    private func loadFromBackend() async {
        guard let apiService = investorWatchlistAPIService,
              let investorId = currentInvestorId else {
            return
        }

        do {
            let backendWatchlist = try await apiService.fetchWatchlist(for: investorId)
            await MainActor.run {
                // Merge backend watchlist with local (avoid duplicates by traderId)
                let existingIds = Set(watchlist.map { $0.id })
                let newTraders = backendWatchlist.filter { !existingIds.contains($0.id) }
                watchlist.append(contentsOf: newTraders)
                print("✅ Loaded \(backendWatchlist.count) traders from backend watchlist")
            }
        } catch {
            print("⚠️ Failed to load investor watchlist from backend: \(error.localizedDescription)")
        }
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

        // Sync to backend (write-through pattern)
        if let apiService = investorWatchlistAPIService,
           let investorId = currentInvestorId {
            Task.detached { [apiService, trader, investorId] in
                do {
                    _ = try await apiService.saveWatchlistItem(trader, investorId: investorId)
                    print("✅ Investor watchlist item saved to backend: \(trader.name)")
                } catch {
                    print("⚠️ Failed to sync investor watchlist item to backend: \(error.localizedDescription)")
                }
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

        // Sync deletion to backend (write-through pattern)
        if let apiService = investorWatchlistAPIService,
           let investorId = currentInvestorId {
            Task.detached { [apiService, traderId, investorId] in
                do {
                    try await apiService.removeWatchlistItem(traderId, investorId: investorId)
                    print("✅ Investor watchlist item deletion synced to backend: \(traderId)")
                } catch {
                    print("⚠️ Failed to sync investor watchlist item deletion to backend: \(error.localizedDescription)")
                }
            }
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

        // Sync deletion to backend (remove all items)
        if let apiService = investorWatchlistAPIService,
           let investorId = currentInvestorId {
            Task.detached { [apiService, investorId] in
                do {
                    // Fetch all items and delete them
                    let items = try await apiService.fetchWatchlist(for: investorId)
                    for item in items {
                        try? await apiService.removeWatchlistItem(item.id, investorId: investorId)
                    }
                    print("✅ Investor watchlist cleared on backend")
                } catch {
                    print("⚠️ Failed to clear investor watchlist on backend: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Backend Synchronization

    func syncToBackend() async {
        guard let apiService = investorWatchlistAPIService,
              let investorId = currentInvestorId else {
            print("⚠️ InvestorWatchlistAPIService or investorId not available for sync")
            return
        }

        print("📤 Syncing investor watchlist to backend...")

        // Sync all current watchlist items
        let itemsToSync = await MainActor.run { watchlist }

        for item in itemsToSync {
            do {
                _ = try await apiService.saveWatchlistItem(item, investorId: investorId)
            } catch {
                print("⚠️ Failed to sync investor watchlist item \(item.id): \(error.localizedDescription)")
            }
        }

        print("✅ Investor watchlist sync completed")
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
