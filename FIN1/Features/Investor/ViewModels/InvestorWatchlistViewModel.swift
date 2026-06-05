import Combine
import Foundation

// MARK: - Investor Watchlist View Model
/// ViewModel for InvestorWatchlistView following MVVM architecture
@MainActor
final class InvestorWatchlistViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var watchedTraders: [InvestorTrader] = []

    // MARK: - Dependencies
    private let watchlistService: any InvestorWatchlistServiceProtocol
    private let traderDataService: any TraderDataServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(watchlistService: any InvestorWatchlistServiceProtocol, traderDataService: any TraderDataServiceProtocol) {
        self.watchlistService = watchlistService
        self.traderDataService = traderDataService
        self.setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Observe watchlist changes via NotificationCenter (service posts notifications)
        NotificationCenter.default.publisher(for: .init("WatchlistUpdated"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateWatchedTraders()
            }
            .store(in: &self.cancellables)

        // Initial load
        self.updateWatchedTraders()
    }

    private func updateWatchedTraders() {
        self.watchedTraders = self.mapWatchlistToTraders()
    }

    // MARK: - Business Logic Methods

    /// Maps watchlist items to catalog traders (prefer `TraderDataService` hydration).
    private func mapWatchlistToTraders() -> [InvestorTrader] {
        self.watchlistService.watchlist.compactMap { item in
            if let catalog = self.traderDataService.getTrader(by: item.id) {
                return catalog
            }
            let parseId = TraderParseIdentity.isLikelyParseObjectId(item.id) ? item.id : nil
            let username = item.name.replacingOccurrences(of: " ", with: "").lowercased()
            return InvestorTrader(
                catalogId: item.id,
                parseUserId: parseId,
                name: item.name,
                username: username.isEmpty ? item.id : username,
                specialization: item.tradingStrategy,
                experienceYears: 0,
                isVerified: true,
                riskLevel: .medium,
                demoMetrics: TraderDemoMetrics(
                    performance: item.performance,
                    totalTrades: 0,
                    winRate: 0,
                    averageReturn: item.performance,
                    totalReturn: item.performance,
                    recentTrades: [],
                    lastNTrades: 0,
                    successfulTradesInLastN: 0,
                    averageReturnLastNTrades: 0,
                    consecutiveWinningTrades: 0,
                    maxDrawdown: 0,
                    sharpeRatio: 0
                ),
                isFromMockCatalog: false
            )
        }
    }

    // MARK: - Error Handling

    func clearError() {
        self.errorMessage = nil
    }

    func showError(_ error: AppError) {
        self.errorMessage = error.errorDescription ?? "An error occurred"
    }
}
