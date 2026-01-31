import SwiftUI

// MARK: - Trader Watchlist View Wrapper
/// Wrapper to properly inject services from environment
struct TraderWatchlistViewWrapper: View {
    @Environment(\.appServices) private var services

    var body: some View {
        TraderWatchlistView(securitiesWatchlistService: services.securitiesWatchlistService as? SecuritiesWatchlistService)
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
                    traderWatchlistContent
                }

                // Success message overlay
                TraderWatchlistSuccessMessageOverlay(
                    message: successMessage,
                    isVisible: showSuccessMessage
                )
            }
            .navigationTitle("Watchlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showSecuritiesSearch = true
                    }, label: {
                        HStack(spacing: ResponsiveDesign.spacing(4)) {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                        }
                        .foregroundColor(AppTheme.accentLightBlue)
                    })
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !watchlistService.watchlist.isEmpty {
                        Button("Clear All") {
                            showClearAllConfirmation = true
                        }
                        .foregroundColor(AppTheme.accentRed)
                    }
                }
            }
        }
        .alert("Remove Security", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                removeSecurity()
            }
        } message: {
            Text("Are you sure you want to remove this security from your watchlist?")
        }
        .alert("Clear All Securities", isPresented: $showClearAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllSecurities()
            }
        } message: {
            Text("Are you sure you want to remove all securities from your watchlist?")
        }
        .sheet(item: $selectedSecurityForOrder) { security in
            BuyOrderViewWrapper(
                searchResult: security,
                traderService: services.traderService,
                cashBalanceService: services.cashBalanceService,
                configurationService: services.configurationService,
                investmentQuantityCalculationService: services.investmentQuantityCalculationService,
                investmentService: services.investmentService,
                userService: services.userService,
                traderDataService: services.traderDataService
            )
        }
        .sheet(isPresented: $showSecuritiesSearch) {
            SecuritiesSearchView(services: services)
        }
    }

    // MARK: - Main Content
    private var traderWatchlistContent: some View {
        ScrollView {
            LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                if watchlistService.watchlist.isEmpty {
                    TraderWatchlistEmptyState()
                } else {
                    ForEach(Array(watchlistService.watchlist.enumerated()), id: \.element.wkn) { index, security in
                        TraderWatchedSecurityCard(
                            security: security,
                            position: index + 1,
                            onRemove: {
                                itemToRemove = security
                                showRemoveConfirmation = true
                            },
                            onKaufenTapped: {
                                selectedSecurityForOrder = security
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
            try? await watchlistService.removeFromWatchlist(security.wkn)
            await MainActor.run {
                showSuccessMessage("\(security.wkn) removed from watchlist")
                itemToRemove = nil
            }
        }
    }

    private func clearAllSecurities() {
        Task {
            try? await watchlistService.clearWatchlist()
            await MainActor.run {
                showSuccessMessage("All securities removed from watchlist")
            }
        }
    }

    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccessMessage = true

        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showSuccessMessage = false
        }
    }
}

// MARK: - Preview
#Preview {
    TraderWatchlistViewWrapper()
        .environment(\.appServices, AppServices.live)
}
