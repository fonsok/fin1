import Foundation
import SwiftUI

struct InvestorDiscoveryView: View {
    @StateObject private var viewModel: InvestorDiscoveryViewModel
    @StateObject private var savedFiltersManager: SavedFiltersManager
    @Environment(\.appServices) private var appServices
    @Environment(\.themeManager) private var themeManager

    init(viewModel: InvestorDiscoveryViewModel, savedFiltersManager: SavedFiltersManager = SavedFiltersManager()) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self._savedFiltersManager = StateObject(wrappedValue: savedFiltersManager)
    }
    @State private var searchText = ""
    @State private var showMoreFilters = false
    @State private var showSavedFilters = false
    @State private var showCreateCombination = false
    @State private var activeFilters: [IndividualFilterCriteria] = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                self.investorDiscoveryContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Find Trader")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !self.activeFilters.isEmpty {
                        Button("Apply (\(self.activeFilters.count))") {
                            self.applyActiveFilters()
                        }
                        .foregroundColor(AppTheme.accentGreen)
                    }
                }
            }
            .task {
                self.viewModel.loadTraders()
                self.viewModel.setSavedFiltersToCheck(self.savedFiltersManager.savedFilters)
            }
            .onChange(of: self.savedFiltersManager.savedFilters) { _, newFilters in
                self.viewModel.setSavedFiltersToCheck(newFilters)
                // Also check current activeFilters against the updated saved filters
                self.viewModel.checkAndUpdateAppliedFilter(for: self.activeFilters)
            }
            .onChange(of: self.activeFilters) { _, newFilters in
                // Check if filters match any saved combination when they change
                self.viewModel.checkAndUpdateAppliedFilter(for: newFilters)
            }
            .sheet(isPresented: self.$showSavedFilters) {
                SavedFiltersView(
                    savedFiltersManager: self.savedFiltersManager,
                    onActivateFilter: { savedFilter in
                        self.viewModel.applySavedFilter(savedFilter, to: &self.activeFilters)
                        self.showSavedFilters = false
                    },
                    currentlyAppliedFilterID: self.viewModel.getAppliedFilterID()
                )
            }
            .sheet(isPresented: self.$showCreateCombination) {
                CreateFilterCombinationView(
                    savedFiltersManager: self.savedFiltersManager,
                    activeFilters: self.$activeFilters
                )
            }
        }
    }

    // MARK: - Investor Discovery Content

    private var investorDiscoveryContent: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                // Search Section
                SearchSection(
                    searchText: self.$searchText,
                    onSearchChange: { newValue in
                        self.viewModel.handleSearchChange(newValue)
                    },
                    onClearSearch: {
                        self.searchText = ""
                        self.viewModel.clearSearch()
                    }
                )

                Divider()
                    .background(AppTheme.fontColor.opacity(0.5))
                    .padding(.vertical, ResponsiveDesign.spacing(8))

                // Saved Filters Section
                SavedFiltersSection(
                    savedFilters: self.savedFiltersManager.savedFilters,
                    activeFilters: self.activeFilters,
                    onViewAll: { self.showSavedFilters = true },
                    onCreateNew: { self.showCreateCombination = true },
                    onApplyFilter: { savedFilter in
                        self.viewModel.applySavedFilter(savedFilter, to: &self.activeFilters)
                    },
                    onDeleteFilter: { savedFilter in
                        self.savedFiltersManager.removeFilter(savedFilter)
                    },
                    currentlyAppliedFilterID: self.viewModel.getAppliedFilterID()
                )

                Divider()
                    .background(AppTheme.fontColor.opacity(0.5))
                    .padding(.vertical, ResponsiveDesign.spacing(8))

                // Active Filters Section
                if !self.activeFilters.isEmpty {
                    ActiveFiltersSection(
                        activeFilters: self.activeFilters,
                        currentlyAppliedFilterID: self.viewModel.getAppliedFilterID(),
                        currentFilterName: self.viewModel.getCurrentFilterName(from: self.savedFiltersManager.savedFilters),
                        onClearAll: {
                            self.viewModel.clearAllFilters(&self.activeFilters)
                        },
                        onRemoveFilter: { filterType in
                            self.viewModel.handleRemoveFilter(filterType, from: &self.activeFilters)
                        }
                    )

                    Divider()
                        .background(AppTheme.fontColor.opacity(0.5))
                        .padding(.vertical, ResponsiveDesign.spacing(8))
                }

                // Individual Filters Section
                IndividualFiltersSection(
                    activeFilters: self.activeFilters,
                    onAddFilter: { filter in
                        self.viewModel.handleAddFilter(filter, to: &self.activeFilters)
                    },
                    onRemoveFilter: { filterType in
                        self.viewModel.handleRemoveFilter(filterType, from: &self.activeFilters)
                    },
                    onShowMoreFilters: {
                        self.showMoreFilters = true
                    }
                )

                // Hitlist Table Section - Show results when filters are active OR when search query exists
                if !self.activeFilters.isEmpty || !self.viewModel.searchQuery.isEmpty {
                    Divider()
                        .background(AppTheme.fontColor.opacity(0.5))
                        .padding(.vertical, ResponsiveDesign.spacing(8))
                }

                // Hitlist Table Section - Show results when filters are active OR when search query exists
                if !self.activeFilters.isEmpty || !self.viewModel.searchQuery.isEmpty {
                    HitlistTableSection(
                        traders: self.viewModel.filteredTraders(by: self.activeFilters, searchQuery: self.viewModel.searchQuery),
                        activeFilters: self.activeFilters,
                        appServices: self.appServices,
                        viewModel: self.viewModel
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            .padding(.top, ResponsiveDesign.spacing(8))
            .padding(.bottom, ResponsiveDesign.spacing(16))
        }
        .scrollDismissesKeyboard(.interactively) // iOS 16+ native keyboard dismissal - no gesture conflicts
        .sheet(isPresented: self.$showMoreFilters) {
            AdvancedFiltersView()
        }
    }

    // MARK: - Helper Functions

    private func applyActiveFilters() {
        let combination = FilterCombination(name: "Custom Combination", filters: activeFilters)
        print("Applying filter combination: \(combination.name) with \(combination.filters.count) filters")
    }
}

// MARK: - Hitlist Table Section

struct HitlistTableSection: View {
    let traders: [MockTrader]
    let appServices: AppServices
    let viewModel: InvestorDiscoveryViewModel
    @State private var selectedTraderID: TraderIDItem?
    @State private var watchlistTick: Int = 0
    @State private var showConfirmation: Bool = false
    @State private var confirmationTitle: String = ""
    @State private var confirmationIcon: String = "star.fill"
    @State private var showError: Bool = false
    @State private var errorTitle: String = ""
    @State private var busyUsernames: Set<String> = []

    init(traders: [MockTrader], activeFilters: [IndividualFilterCriteria], appServices: AppServices, viewModel: InvestorDiscoveryViewModel) {
        self.traders = traders
        self.appServices = appServices
        self.viewModel = viewModel
        // Note: activeFilters parameter kept for API consistency but not used
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Text("Results (\(self.traders.count))")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.regular)
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
            }

            if self.traders.isEmpty {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Text("No traders match the current filter criteria")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .responsivePadding()
                .background(AppTheme.systemTertiaryBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
            } else {
                // Use the same table format as "Top Recent Trades"
                ScrollView(.horizontal, showsIndicators: false) {
                    DataTable.traderPerformanceTable(
                        rows: TableDataFactory.createTraderPerformanceRows(
                            from: self.viewModel.createTraderPerformanceData(from: self.traders),
                            onTraderTap: { username in
                                print("📌 [Hitlist] onTraderTap username=\(username)")
                                // Find the trader ID from the username
                                if let traderID = viewModel.getTraderID(for: username, traderDataService: appServices.traderDataService) {
                                    self.selectedTraderID = TraderIDItem(id: traderID)
                                }
                            },
                            onWatchlistToggle: { username, isWatched in
                                print("⭐️ [Hitlist] onWatchlistToggle username=\(username), isWatched(next)=\(isWatched)")
                                // Find the trader ID from the username
                                if let traderID = viewModel.getTraderID(for: username, traderDataService: appServices.traderDataService) {
                                    self.busyUsernames.insert(username)
                                    self.handleWatchlistToggle(traderID: traderID, isWatched: isWatched, username: username)
                                }
                            },
                            watchlistStatus: self.viewModel.getWatchlistStatus(
                                watchlistService: self.appServices.watchlistService,
                                traderDataService: self.appServices.traderDataService
                            ),
                            busyStatus: self.viewModel.getBusyStatus(from: self.busyUsernames)
                        ),
                        showTraderColumn: true,
                        isInteractive: false
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onChange(of: self.appServices.watchlistService.watchlist.count) { _, _ in
            // Trigger view refresh when watchlist changes
            print("🔄 [Hitlist] watchlist count changed -> \(self.appServices.watchlistService.watchlist.count)")
            self.watchlistTick &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("WatchlistUpdated"))) { _ in
            print("🔔 [Hitlist] WatchlistUpdated notification received")
            self.watchlistTick &+= 1
        }
        .sheet(item: self.$selectedTraderID) { traderIDItem in
            TraderNavigationHelper.sheetView(for: traderIDItem.id, appServices: self.appServices)
        }
        .watchlistConfirmation(isShowing: self.showConfirmation, title: self.confirmationTitle, systemImage: self.confirmationIcon)
        .watchlistError(isShowing: self.showError, title: self.errorTitle)
    }

    private func handleWatchlistToggle(traderID: String, isWatched: Bool, username: String) {
        print("➡️ [Hitlist] handleWatchlistToggle traderID=\(traderID), isWatched(next)=\(isWatched)")
        if isWatched {
            // Add to watchlist
            if let trader = appServices.traderDataService.getTrader(by: traderID) {
                let item = WatchlistTraderData(
                    id: traderID,
                    name: trader.username,
                    image: "person.circle.fill",
                    performance: trader.totalReturn,
                    riskClass: .riskClass3,
                    totalInvestors: 0,
                    minimumInvestment: 0,
                    description: trader.specialization,
                    tradingStrategy: trader.specialization,
                    experience: "\(trader.experienceYears) years",
                    dateAdded: Date(),
                    lastUpdated: Date(),
                    isActive: true,
                    notificationsEnabled: false
                )
                Task {
                    print("➕ [Hitlist] adding to watchlist: id=\(item.id), name=\(item.name)")
                    do {
                        try await self.appServices.watchlistService.addToWatchlist(item)
                        let watchlistIds = self.viewModel.getWatchlistIds(watchlistService: self.appServices.watchlistService)
                        print("✅ [Hitlist] add completed. currentIds=\(watchlistIds)")
                        _ = await MainActor.run {
                            self.confirmationTitle = "Added to Watchlist"
                            self.confirmationIcon = "star.fill"
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.showConfirmation = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                withAnimation(.easeOut(duration: 0.25)) { self.showConfirmation = false }
                            }
                        }
                    } catch {
                        _ = await MainActor.run {
                            self.errorTitle = "Failed to add to Watchlist"
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.showError = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeOut(duration: 0.25)) { self.showError = false }
                            }
                        }
                    }
                    _ = await MainActor.run {
                        self.busyUsernames.remove(username)
                    }
                }

                // Provide haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        } else {
            // Remove from watchlist
            Task {
                print("➖ [Hitlist] removing from watchlist: id=\(traderID)")
                do {
                    try await self.appServices.watchlistService.removeFromWatchlist(traderID)
                    let watchlistIds = self.viewModel.getWatchlistIds(watchlistService: self.appServices.watchlistService)
                    print("✅ [Hitlist] remove completed. currentIds=\(watchlistIds)")
                    _ = await MainActor.run {
                        self.confirmationTitle = "Removed from Watchlist"
                        self.confirmationIcon = "star"
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.showConfirmation = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            withAnimation(.easeOut(duration: 0.25)) { self.showConfirmation = false }
                        }
                    }
                } catch {
                    _ = await MainActor.run {
                        self.errorTitle = "Failed to remove from Watchlist"
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.showError = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.25)) { self.showError = false }
                        }
                    }
                }
                _ = await MainActor.run {
                    self.busyUsernames.remove(username)
                }
            }

            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}
#Preview {
    NavigationStack {
        InvestorDiscoveryViewWrapper()
    }
}
