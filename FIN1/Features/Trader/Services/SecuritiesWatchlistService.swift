import Foundation
import Combine

// MARK: - Securities Watchlist Service Implementation
/// Handles securities watchlist operations and management
final class SecuritiesWatchlistService: SecuritiesWatchlistServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    static let shared = SecuritiesWatchlistService()

    @Published var watchlist: [SearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?
    private let marketDataService: (any MarketDataServiceProtocol)?
    private let userService: (any UserServiceProtocol)?
    private var watchlistAPIService: WatchlistAPIServiceProtocol?
    private var cancellables = Set<AnyCancellable>()

    init(
        parseLiveQueryClient: (any ParseLiveQueryClientProtocol)? = nil,
        marketDataService: (any MarketDataServiceProtocol)? = nil,
        userService: (any UserServiceProtocol)? = nil,
        watchlistAPIService: WatchlistAPIServiceProtocol? = nil
    ) {
        self.parseLiveQueryClient = parseLiveQueryClient
        self.marketDataService = marketDataService
        self.userService = userService
        self.watchlistAPIService = watchlistAPIService
        loadMockData()
        setupMarketDataObserver()
    }

    /// Configure the API service for backend synchronization
    func configure(watchlistAPIService: WatchlistAPIServiceProtocol) {
        self.watchlistAPIService = watchlistAPIService
    }

    /// Returns the current user's ID
    private var currentUserId: String? {
        userService?.currentUser?.id
    }

    // MARK: - ServiceLifecycle
    func start() {
        Task {
            try? await loadWatchlist()
            await subscribeToMarketDataUpdates()
        }
    }

    func stop() {
        // Clean up any ongoing operations
    }

    func reset() {
        watchlist.removeAll()
        errorMessage = nil
    }

    // MARK: - Watchlist Data Management

    func loadWatchlist() async throws {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        // Try to fetch from backend first
        if let apiService = watchlistAPIService,
           let userId = currentUserId {
            do {
                let fetchedItems = try await apiService.fetchWatchlist(for: userId)
                await MainActor.run {
                    self.watchlist = fetchedItems
                    self.isLoading = false
                }
                return
            } catch {
                print("⚠️ Failed to fetch watchlist from backend, using local: \(error.localizedDescription)")
            }
        }

        // Fallback to mock data
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        await MainActor.run {
            loadWatchlistSync()
            isLoading = false
        }
    }

    func refreshWatchlist() async throws {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        await MainActor.run {
            loadWatchlistSync()
            isLoading = false
        }
    }

    // MARK: - Watchlist Management

    func addToWatchlist(_ searchResult: SearchResult) async throws {
        await MainActor.run {
            // Check if already in watchlist
            if !watchlist.contains(where: { $0.wkn == searchResult.wkn }) {
                watchlist.append(searchResult)

                // Show notification
                NotificationCenter.default.post(
                    name: .watchlistItemAdded,
                    object: searchResult
                )

                print("✅ Added to watchlist: \(searchResult.wkn)")
            }
        }

        // Sync to backend (write-through pattern)
        if let apiService = watchlistAPIService,
           let userId = currentUserId {
            Task { [apiService, searchResult, userId] in
                do {
                    _ = try await apiService.saveWatchlistItem(searchResult, userId: userId)
                    print("✅ Watchlist item synced to backend: \(searchResult.wkn)")
                } catch {
                    print("⚠️ Failed to sync watchlist item to backend: \(error.localizedDescription)")
                }
            }
        }
    }

    func removeFromWatchlist(_ wkn: String) async throws {
        await MainActor.run {
            watchlist.removeAll { $0.wkn == wkn }
            print("❌ Removed from watchlist: \(wkn)")
        }

        // Sync deletion to backend (write-through pattern)
        if let apiService = watchlistAPIService,
           let userId = currentUserId {
            Task { [apiService, wkn, userId] in
                do {
                    try await apiService.removeWatchlistItem(wkn, userId: userId)
                    print("✅ Watchlist item deletion synced to backend: \(wkn)")
                } catch {
                    print("⚠️ Failed to sync watchlist item deletion to backend: \(error.localizedDescription)")
                }
            }
        }
    }

    func clearWatchlist() async throws {
        await MainActor.run {
            watchlist.removeAll()
            print("🗑️ Cleared watchlist")
        }

        // Sync deletion to backend (remove all items)
        if let apiService = watchlistAPIService,
           let userId = currentUserId {
            Task { [apiService, userId] in
                do {
                    // Fetch all items and delete them
                    let items = try await apiService.fetchWatchlist(for: userId)
                    for item in items {
                        try? await apiService.removeWatchlistItem(item.wkn, userId: userId)
                    }
                    print("✅ Watchlist cleared on backend")
                } catch {
                    print("⚠️ Failed to clear watchlist on backend: \(error.localizedDescription)")
                }
            }
        }
    }

    func isInWatchlist(_ wkn: String) -> Bool {
        return watchlist.contains { $0.wkn == wkn }
    }

    // MARK: - Backend Synchronization

    func syncToBackend() async {
        guard let apiService = watchlistAPIService,
              let userId = currentUserId else {
            print("⚠️ WatchlistAPIService or userId not available for sync")
            return
        }

        print("📤 Syncing watchlist to backend...")

        // Sync all current watchlist items
        let itemsToSync = await MainActor.run { watchlist }

        for item in itemsToSync {
            do {
                _ = try await apiService.saveWatchlistItem(item, userId: userId)
            } catch {
                print("⚠️ Failed to sync watchlist item \(item.wkn): \(error.localizedDescription)")
            }
        }

        print("✅ Watchlist sync completed")
    }

    // MARK: - Private Methods

    private func loadMockData() {
        loadWatchlistSync()
    }

    private func loadWatchlistSync() {
        // In real app, this would load from API
        // For now, keep existing watchlist to prevent it from disappearing
        // when app becomes active (e.g., returning from browser)
        // watchlist = [] // Commented out to preserve watchlist
    }

    // MARK: - Market Data Live Updates

    private func setupMarketDataObserver() {
        // Observe market data updates
        NotificationCenter.default.publisher(for: .marketDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let symbol = userInfo["symbol"] as? String else {
                    return
                }

                // Update watchlist items with new market data
                Task { @MainActor in
                    self.updateWatchlistMarketData(symbol: symbol)
                }
            }
            .store(in: &cancellables)
    }

    private func subscribeToMarketDataUpdates() async {
        // Get all unique underlying assets from watchlist
        let symbols = watchlist.compactMap { $0.underlyingAsset }
            .removingDuplicates()

        guard !symbols.isEmpty else { return }

        // Subscribe to market data updates for watchlist symbols
        await marketDataService?.subscribeToMarketData(symbols: symbols)
    }

    private func updateWatchlistMarketData(symbol: String) {
        // Update market data for watchlist items with matching underlying asset
        // Note: SearchResult doesn't have mutable market data, so we'd need to reload
        // or update the view model that displays the watchlist
        print("📊 SecuritiesWatchlistService: Market data updated for \(symbol)")

        // Post notification to update watchlist views
        NotificationCenter.default.post(
            name: .watchlistMarketDataUpdated,
            object: nil,
            userInfo: ["symbol": symbol]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchlistMarketDataUpdated = Notification.Name("watchlistMarketDataUpdated")
}

// MARK: - Array Extension

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
