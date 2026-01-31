import SwiftUI
import Foundation

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

                investorDiscoveryContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Find Trader")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !activeFilters.isEmpty {
                        Button("Apply (\(activeFilters.count))") {
                            applyActiveFilters()
                        }
                        .foregroundColor(AppTheme.accentGreen)
                    }
                }
            }
            .task {
                viewModel.loadTraders()
                viewModel.setSavedFiltersToCheck(savedFiltersManager.savedFilters)
            }
            .onChange(of: savedFiltersManager.savedFilters) { _, newFilters in
                viewModel.setSavedFiltersToCheck(newFilters)
                // Also check current activeFilters against the updated saved filters
                viewModel.checkAndUpdateAppliedFilter(for: activeFilters)
            }
            .onChange(of: activeFilters) { _, newFilters in
                // Check if filters match any saved combination when they change
                viewModel.checkAndUpdateAppliedFilter(for: newFilters)
            }
            .sheet(isPresented: $showSavedFilters) {
                SavedFiltersView(
                    savedFiltersManager: savedFiltersManager,
                    onActivateFilter: { savedFilter in
                        viewModel.applySavedFilter(savedFilter, to: &activeFilters)
                        showSavedFilters = false
                    },
                    currentlyAppliedFilterID: viewModel.getAppliedFilterID()
                )
            }
            .sheet(isPresented: $showCreateCombination) {
                CreateFilterCombinationView(
                    savedFiltersManager: savedFiltersManager,
                    activeFilters: $activeFilters
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
                    searchText: $searchText,
                    onSearchChange: { newValue in
                        viewModel.handleSearchChange(newValue)
                    },
                    onClearSearch: {
                        searchText = ""
                        viewModel.clearSearch()
                    }
                )

                Divider()
                    .background(AppTheme.fontColor.opacity(0.5))
                    .padding(.vertical, ResponsiveDesign.spacing(8))

                // Saved Filters Section
                SavedFiltersSection(
                    savedFilters: savedFiltersManager.savedFilters,
                    activeFilters: activeFilters,
                    onViewAll: { showSavedFilters = true },
                    onCreateNew: { showCreateCombination = true },
                    onApplyFilter: { savedFilter in
                        viewModel.applySavedFilter(savedFilter, to: &activeFilters)
                    },
                    onDeleteFilter: { savedFilter in
                        savedFiltersManager.removeFilter(savedFilter)
                    },
                    currentlyAppliedFilterID: viewModel.getAppliedFilterID()
                )

                Divider()
                    .background(AppTheme.fontColor.opacity(0.5))
                    .padding(.vertical, ResponsiveDesign.spacing(8))

                // Active Filters Section
                if !activeFilters.isEmpty {
                    ActiveFiltersSection(
                        activeFilters: activeFilters,
                        currentlyAppliedFilterID: viewModel.getAppliedFilterID(),
                        currentFilterName: viewModel.getCurrentFilterName(from: savedFiltersManager.savedFilters),
                        onClearAll: {
                            viewModel.clearAllFilters(&activeFilters)
                        },
                        onRemoveFilter: { filterType in
                            viewModel.handleRemoveFilter(filterType, from: &activeFilters)
                        }
                    )

                    Divider()
                        .background(AppTheme.fontColor.opacity(0.5))
                        .padding(.vertical, ResponsiveDesign.spacing(8))
                }

                // Individual Filters Section
                IndividualFiltersSection(
                    activeFilters: activeFilters,
                    onAddFilter: { filter in
                        viewModel.handleAddFilter(filter, to: &activeFilters)
                    },
                    onRemoveFilter: { filterType in
                        viewModel.handleRemoveFilter(filterType, from: &activeFilters)
                    },
                    onShowMoreFilters: {
                        showMoreFilters = true
                    }
                )

                // Hitlist Table Section - Show results when filters are active OR when search query exists
                if !activeFilters.isEmpty || !viewModel.searchQuery.isEmpty {
                    Divider()
                        .background(AppTheme.fontColor.opacity(0.5))
                        .padding(.vertical, ResponsiveDesign.spacing(8))
                }

                // Hitlist Table Section - Show results when filters are active OR when search query exists
                if !activeFilters.isEmpty || !viewModel.searchQuery.isEmpty {
                    HitlistTableSection(
                        traders: viewModel.filteredTraders(by: activeFilters, searchQuery: viewModel.searchQuery),
                        activeFilters: activeFilters,
                        appServices: appServices,
                        viewModel: viewModel
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            .padding(.top, ResponsiveDesign.spacing(8))
            .padding(.bottom, ResponsiveDesign.spacing(16))
        }
        .scrollDismissesKeyboard(.interactively) // iOS 16+ native keyboard dismissal - no gesture conflicts
        .sheet(isPresented: $showMoreFilters) {
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
                Text("Results (\(traders.count))")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.regular)
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
            }

            if traders.isEmpty {
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
                            from: viewModel.createTraderPerformanceData(from: traders),
                            onTraderTap: { username in
                                print("📌 [Hitlist] onTraderTap username=\(username)")
                                // Find the trader ID from the username
                                if let traderID = viewModel.getTraderID(for: username, traderDataService: appServices.traderDataService) {
                                    selectedTraderID = TraderIDItem(id: traderID)
                                }
                            },
                            onWatchlistToggle: { username, isWatched in
                                print("⭐️ [Hitlist] onWatchlistToggle username=\(username), isWatched(next)=\(isWatched)")
                                // Find the trader ID from the username
                                if let traderID = viewModel.getTraderID(for: username, traderDataService: appServices.traderDataService) {
                                    busyUsernames.insert(username)
                                    handleWatchlistToggle(traderID: traderID, isWatched: isWatched, username: username)
                                }
                            },
                            watchlistStatus: viewModel.getWatchlistStatus(watchlistService: appServices.watchlistService, traderDataService: appServices.traderDataService),
                            busyStatus: viewModel.getBusyStatus(from: busyUsernames)
                        ),
                        showTraderColumn: true,
                        isInteractive: false
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onChange(of: appServices.watchlistService.watchlist.count) { _, _ in
            // Trigger view refresh when watchlist changes
            print("🔄 [Hitlist] watchlist count changed -> \(appServices.watchlistService.watchlist.count)")
            watchlistTick &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("WatchlistUpdated"))) { _ in
            print("🔔 [Hitlist] WatchlistUpdated notification received")
            watchlistTick &+= 1
        }
        .sheet(item: $selectedTraderID) { traderIDItem in
            TraderNavigationHelper.sheetView(for: traderIDItem.id, appServices: appServices)
        }
        .watchlistConfirmation(isShowing: showConfirmation, title: confirmationTitle, systemImage: confirmationIcon)
        .watchlistError(isShowing: showError, title: errorTitle)
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
                        try await appServices.watchlistService.addToWatchlist(item)
                        let watchlistIds = viewModel.getWatchlistIds(watchlistService: appServices.watchlistService)
                        print("✅ [Hitlist] add completed. currentIds=\(watchlistIds)")
                        _ = await MainActor.run {
                            confirmationTitle = "Added to Watchlist"
                            confirmationIcon = "star.fill"
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showConfirmation = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                withAnimation(.easeOut(duration: 0.25)) { showConfirmation = false }
                            }
                        }
                    } catch {
                        _ = await MainActor.run {
                            errorTitle = "Failed to add to Watchlist"
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showError = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeOut(duration: 0.25)) { showError = false }
                            }
                        }
                    }
                    _ = await MainActor.run {
                        busyUsernames.remove(username)
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
                    try await appServices.watchlistService.removeFromWatchlist(traderID)
                    let watchlistIds = viewModel.getWatchlistIds(watchlistService: appServices.watchlistService)
                    print("✅ [Hitlist] remove completed. currentIds=\(watchlistIds)")
                    _ = await MainActor.run {
                        confirmationTitle = "Removed from Watchlist"
                        confirmationIcon = "star"
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showConfirmation = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            withAnimation(.easeOut(duration: 0.25)) { showConfirmation = false }
                        }
                    }
                } catch {
                    _ = await MainActor.run {
                        errorTitle = "Failed to remove from Watchlist"
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showError = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.25)) { showError = false }
                        }
                    }
                }
                _ = await MainActor.run {
                    busyUsernames.remove(username)
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
