import SwiftUI

// MARK: - Trader Watchlist View Wrapper
/// Wrapper to properly inject services from environment
struct TraderWatchlistViewWrapper: View {
    @Environment(\.appServices) private var services

    var body: some View {
        TraderWatchlistView(securitiesWatchlistService: self.services.securitiesWatchlistService as? SecuritiesWatchlistService)
    }
}

// MARK: - Trader Watchlist View
/// Dedicated watchlist view for Traders to track watched securities
struct TraderWatchlistView: View {
    @Environment(\.appServices) private var services
    @ObservedObject private var watchlistService: SecuritiesWatchlistService
    @State private var showRemoveConfirmation = false
    @State private var showClearAllConfirmation = false
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    @State private var itemToRemove: SearchResult?
    @State private var selectedSecurityForOrder: SearchResult?
    @State private var showSecuritiesSearch = false

    init(securitiesWatchlistService: SecuritiesWatchlistService?) {
        // Service must be provided - wrapper handles injection
        guard let service = securitiesWatchlistService else {
            fatalError("TraderWatchlistView must be initialized with service. Use TraderWatchlistViewWrapper instead.")
        }
        self._watchlistService = ObservedObject(wrappedValue: service)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    // Trader Watchlist Content
                    self.traderWatchlistContent
                }

                // Success message overlay
                TraderWatchlistSuccessMessageOverlay(
                    message: self.successMessage,
                    isVisible: self.showSuccessMessage
                )
            }
            .navigationTitle("Watchlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        self.showSecuritiesSearch = true
                    }, label: {
                        HStack(spacing: ResponsiveDesign.spacing(4)) {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                        }
                        .foregroundColor(AppTheme.accentLightBlue)
                    })
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !self.watchlistService.watchlist.isEmpty {
                        Button("Clear All") {
                            self.showClearAllConfirmation = true
                        }
                        .foregroundColor(AppTheme.accentRed)
                    }
                }
            }
        }
        .alert("Remove Security", isPresented: self.$showRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                self.removeSecurity()
            }
        } message: {
            Text("Are you sure you want to remove this security from your watchlist?")
        }
        .alert("Clear All Securities", isPresented: self.$showClearAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                self.clearAllSecurities()
            }
        } message: {
            Text("Are you sure you want to remove all securities from your watchlist?")
        }
        .sheet(item: self.$selectedSecurityForOrder) { security in
            BuyOrderViewWrapper(
                searchResult: security,
                traderService: self.services.traderService,
                cashBalanceService: self.services.cashBalanceService,
                configurationService: self.services.configurationService,
                investmentQuantityCalculationService: self.services.investmentQuantityCalculationService,
                investmentService: self.services.investmentService,
                userService: self.services.userService,
                traderDataService: self.services.traderDataService
            )
        }
        .sheet(isPresented: self.$showSecuritiesSearch) {
            SecuritiesSearchView(services: self.services)
        }
    }

    // MARK: - Main Content
    private var traderWatchlistContent: some View {
        ScrollView {
            LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                if self.watchlistService.watchlist.isEmpty {
                    TraderWatchlistEmptyState()
                } else {
                    ForEach(Array(self.watchlistService.watchlist.enumerated()), id: \.element.wkn) { index, security in
                        TraderWatchedSecurityCard(
                            security: security,
                            position: index + 1,
                            onRemove: {
                                self.itemToRemove = security
                                self.showRemoveConfirmation = true
                            },
                            onKaufenTapped: {
                                self.selectedSecurityForOrder = security
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, ResponsiveDesign.spacing(16))
            .padding(.top, ResponsiveDesign.spacing(8))
        }
    }

    // MARK: - Actions
    private func removeSecurity() {
        guard let security = itemToRemove else { return }

        Task {
            try? await self.watchlistService.removeFromWatchlist(security.wkn)
            await MainActor.run {
                self.showSuccessMessage("\(security.wkn) removed from watchlist")
                self.itemToRemove = nil
            }
        }
    }

    private func clearAllSecurities() {
        Task {
            try? await self.watchlistService.clearWatchlist()
            await MainActor.run {
                self.showSuccessMessage("All securities removed from watchlist")
            }
        }
    }

    private func showSuccessMessage(_ message: String) {
        self.successMessage = message
        self.showSuccessMessage = true

        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.showSuccessMessage = false
        }
    }
}

// MARK: - Preview
#Preview {
    TraderWatchlistViewWrapper()
        .environment(\.appServices, AppServices.live)
}
