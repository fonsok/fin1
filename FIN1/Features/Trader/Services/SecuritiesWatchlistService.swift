import Foundation
import Combine

// MARK: - Securities Watchlist Service Implementation
/// Handles securities watchlist operations and management
final class SecuritiesWatchlistService: SecuritiesWatchlistServiceProtocol, ServiceLifecycle {
    static let shared = SecuritiesWatchlistService()

    @Published var watchlist: [SearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?
    private let marketDataService: (any MarketDataServiceProtocol)?
    private var cancellables = Set<AnyCancellable>()

    init(
        parseLiveQueryClient: (any ParseLiveQueryClientProtocol)? = nil,
        marketDataService: (any MarketDataServiceProtocol)? = nil
    ) {
        self.parseLiveQueryClient = parseLiveQueryClient
        self.marketDataService = marketDataService
        loadMockData()
        setupMarketDataObserver()
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
    }

    func removeFromWatchlist(_ wkn: String) async throws {
        await MainActor.run {
            watchlist.removeAll { $0.wkn == wkn }
            print("❌ Removed from watchlist: \(wkn)")
        }
    }

    func clearWatchlist() async throws {
        await MainActor.run {
            watchlist.removeAll()
            print("🗑️ Cleared watchlist")
        }
    }

    func isInWatchlist(_ wkn: String) -> Bool {
        return watchlist.contains { $0.wkn == wkn }
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
