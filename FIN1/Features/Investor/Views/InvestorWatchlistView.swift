import SwiftUI

// MARK: - Investor Watchlist View Wrapper
/// Wrapper to properly inject services from environment
struct InvestorWatchlistViewWrapper: View {
    @Environment(\.appServices) private var services

    var body: some View {
        InvestorWatchlistView(
            watchlistService: services.watchlistService,
            traderDataService: services.traderDataService
        )
    }
}

// MARK: - Investor Watchlist View
/// Dedicated watchlist view for Investors to track watched traders
struct InvestorWatchlistView: View {
    @Environment(\.appServices) private var services
    @StateObject private var viewModel: InvestorWatchlistViewModel
    @State private var watchlistTick: Int = 0
    @State private var showRemoveConfirmation = false
    @State private var showClearAllConfirmation = false
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    @State private var itemToRemove: MockTrader?
    @State private var traderToInvest: MockTrader?
    @Environment(\.themeManager) private var themeManager

    init(watchlistService: any InvestorWatchlistServiceProtocol, traderDataService: any TraderDataServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: InvestorWatchlistViewModel(
            watchlistService: watchlistService,
            traderDataService: traderDataService
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    // Investor Watchlist Content
                    investorWatchlistContent
                }

                // Success Message Overlay
                InvestorWatchlistSuccessMessageOverlay(
                    message: successMessage,
                    isVisible: showSuccessMessage
                )
            }
            .onChange(of: services.watchlistService.watchlist.count) { _, newValue in
                print("🔄 [WatchlistView] watchlist count changed -> \(newValue)")
                watchlistTick &+= 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("WatchlistUpdated"))) { _ in
                print("🔔 [WatchlistView] WatchlistUpdated notification received")
                watchlistTick &+= 1
            }
            .onChange(of: showSuccessMessage) { _, isVisible in
                guard isVisible else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSuccessMessage = false
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Watched Traders")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !watchedTraders.isEmpty {
                        Button(action: {
                            showClearAllConfirmation = true
                        }) {
                            Text("Clear All")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.accentRed)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // TODO: Add search/discover traders functionality
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: ResponsiveDesign.iconSize()))
                            .foregroundColor(AppTheme.accentLightBlue)
                    }
                }
            }
            .confirmationDialog(
                "Remove Trader from Watchlist",
                isPresented: $showRemoveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    removeTrader()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let trader = itemToRemove {
                    Text("Are you sure you want to remove \(trader.name) from your watchlist?")
                }
            }
            .confirmationDialog(
                "Clear All Watched Traders",
                isPresented: $showClearAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    clearAllTraders()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to remove all traders from your watchlist? This action cannot be undone.")
            }
            .sheet(item: $traderToInvest) { trader in
                InvestmentSheet(trader: trader, onInvestmentSuccess: {
                    // Optionally refresh watchlist or show success message
                    traderToInvest = nil
                })
            }
        }
    }

    // MARK: - Investor Watchlist Content
    private var investorWatchlistContent: some View {
        ScrollView {
            LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                if watchedTraders.isEmpty {
                    // Empty State
                    InvestorWatchlistEmptyState()
                } else {
                    // Watched Traders List
                    ForEach(watchedTraders) { trader in
                        InvestorWatchedTraderCard(
                            trader: trader,
                            onRemove: {
                                itemToRemove = trader
                                showRemoveConfirmation = true
                            },
                            onInvest: {
                                traderToInvest = trader
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, ResponsiveDesign.spacing(16))
            .padding(.top, ResponsiveDesign.spacing(16))
            .id(watchlistTick)
        }
    }

    // MARK: - Computed Properties
    private var watchedTraders: [MockTrader] {
        viewModel.watchedTraders
    }

    // MARK: - Actions
    private func removeTrader() {
        guard let trader = itemToRemove else { return }

        Task {
            try? await services.watchlistService.removeFromWatchlist(trader.id.uuidString)
            await MainActor.run {
                showSuccessMessage = true
                successMessage = "Removed \(trader.name) from watchlist"
                itemToRemove = nil
                watchlistTick &+= 1
            }
        }
    }

    private func clearAllTraders() {
        Task {
            try? await services.watchlistService.clearWatchlist()
            await MainActor.run {
                showSuccessMessage = true
                successMessage = "Cleared all watched traders"
                watchlistTick &+= 1
            }
        }
    }
}

// MARK: - Investor Watchlist Empty State
struct InvestorWatchlistEmptyState: View {
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            Image(systemName: "star")
                .font(.system(size: ResponsiveDesign.iconSize() * 3.2))
                .foregroundColor(AppTheme.accentLightBlue.opacity(0.6))

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                Text("No Watched Traders")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Text("Start watching traders to track their performance and get investment insights.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ResponsiveDesign.spacing(32))
            }

            Button(action: {
                // TODO: Navigate to trader discovery
            }) {
                Text("Discover Traders")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .padding(.horizontal, ResponsiveDesign.spacing(24))
                    .padding(.vertical, ResponsiveDesign.spacing(12))
                    .background(AppTheme.accentLightBlue)
                    .cornerRadius(ResponsiveDesign.spacing(8))
            }
        }
        .padding(.top, ResponsiveDesign.spacing(60))
    }
}

// MARK: - Investor Watched Trader Card
struct InvestorWatchedTraderCard: View {
    let trader: MockTrader
    let onRemove: () -> Void
    let onInvest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            // Header with trader info and remove button
            HStack {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text(trader.name)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    Text(trader.specialization)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                }

                Spacer()

                Button(action: onRemove, label: {
                    Image(systemName: "trash")
                        .font(.system(size: ResponsiveDesign.iconSize()))
                        .foregroundColor(AppTheme.tertiaryText)
                })
            }

            // Performance metrics
            HStack(spacing: ResponsiveDesign.spacing(20)) {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    Text("Performance")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.tertiaryText)
                    Text("\(trader.performance, specifier: "%.1f")%")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(trader.performance >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                }

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    Text("Risk Level")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.tertiaryText)
                    Text(trader.riskLevel.displayName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(trader.riskLevel.color)
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Button(action: {
                    // TODO: View trader details
                }) {
                    Text("View Details")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                        .padding(.horizontal, ResponsiveDesign.spacing(16))
                        .padding(.vertical, ResponsiveDesign.spacing(8))
                        .background(AppTheme.accentLightBlue.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.spacing(6))
                }

                Button(action: {
                    onInvest()
                }) {
                    Text("Invest")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .padding(.horizontal, ResponsiveDesign.spacing(16))
                        .padding(.vertical, ResponsiveDesign.spacing(8))
                        .background(AppTheme.buttonColor)
                        .cornerRadius(ResponsiveDesign.spacing(6))
                }

                Spacer()
            }
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Investor Watchlist Success Message Overlay
struct InvestorWatchlistSuccessMessageOverlay: View {
    let message: String
    let isVisible: Bool

    var body: some View {
        if isVisible {
            VStack {
                Spacer()

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.accentGreen)

                    Text(message)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                }
                .padding(.horizontal, ResponsiveDesign.spacing(20))
                .padding(.vertical, ResponsiveDesign.spacing(12))
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
                .shadow(radius: 4)

                Spacer()
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Auto-hide after 2 seconds
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    InvestorWatchlistViewWrapper()
        .environment(\.appServices, AppServices.live)
}
