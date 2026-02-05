import SwiftUI
import Foundation

// MARK: - Investor Discovery ViewModel

@MainActor
final class InvestorDiscoveryViewModel: ObservableObject {
    private var filterPersistence: FilterPersistenceRepositoryProtocol
    private var traderDataService: any TraderDataServiceProtocol
    @Published var allTraders: [MockTrader] = []
    @Published var searchQuery = ""
    private var searchDebounceTask: Task<Void, Never>?

    // MARK: - Init
    init(
        traderDataService: any TraderDataServiceProtocol,
        filterPersistence: FilterPersistenceRepositoryProtocol = FilterPersistenceRepository()
    ) {
        self.traderDataService = traderDataService
        self.filterPersistence = filterPersistence
    }

    // MARK: - DI Reconfiguration (preferred single-container API)
    /// Preferred DI reconfiguration API to avoid parameter drift. Use this instead of legacy overloads.
    func reconfigure(with services: AppServices) {
        self.traderDataService = services.traderDataService
        self.filterPersistence = services.filterPersistenceRepository
    }

    // MARK: - Search Methods

    func loadTraders() {
        allTraders = traderDataService.traders
    }

    func searchTraders(query: String) {
        searchQuery = query
    }

    /// Handles search input with debounce; clears applied filter ID if non-empty after debounce
    func handleSearchChange(_ query: String) {
        let incoming = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            guard let self else { return }
            // 300ms debounce
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                self.searchQuery = incoming
                if !incoming.isEmpty {
                    self.clearAppliedFilterID()
                }
            }
        }
    }

    /// Clears the search query
    func clearSearch() {
        searchQuery = ""
        clearAppliedFilterID()
    }

    // MARK: - Filter Management Methods

    /// Clears the currently applied filter ID using repository
    func clearAppliedFilterID() {
        filterPersistence.clearAppliedFilterID()
    }

    /// Sets the currently applied filter ID using repository
    func setAppliedFilterID(_ filterID: String) {
        filterPersistence.setAppliedFilterID(filterID)
    }

    /// Gets the currently applied filter ID using repository
    func getAppliedFilterID() -> String? {
        return filterPersistence.getAppliedFilterID()
    }

    /// Gets the current filter name from saved filters
    func getCurrentFilterName(from savedFilters: [FilterCombination]) -> String? {
        guard let currentFilterID = getAppliedFilterID(),
              let currentFilter = savedFilters.first(where: { $0.id.uuidString == currentFilterID }) else {
            return nil
        }
        return currentFilter.name
    }

    // MARK: - Watchlist Status Methods

    /// Creates a dictionary mapping usernames to watchlist status
    func getWatchlistStatus(watchlistService: any InvestorWatchlistServiceProtocol, traderDataService: any TraderDataServiceProtocol) -> [String: Bool] {
        var status: [String: Bool] = [:]
        for watchlistItem in watchlistService.watchlist {
            if let trader = traderDataService.getTrader(by: watchlistItem.id) {
                status[trader.username] = true
            }
        }
        return status
    }

    /// Creates a dictionary mapping usernames to busy status
    func getBusyStatus(from busyUsernames: Set<String>) -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: busyUsernames.map { ($0, true) })
    }

    /// Creates trader performance data from traders (sorted and mapped)
    func createTraderPerformanceData(from traders: [MockTrader]) -> [TraderData] {
        traders
            .sorted { $0.performance > $1.performance } // max return on top
            .map { mock in
                TraderData(
                    traderName: mock.username,
                    returnPercentage: String(format: "%.1f%%", mock.performance),
                    successRate: String(format: "%.1f%%", min(max(mock.winRate, 0), 100)),
                    avgReturnPerTrade: String(format: "%.1f%%", mock.averageReturn),
                    isPositive: mock.performance >= 0
                )
            }
    }

    /// Gets trader ID for a given username (business logic)
    func getTraderID(for username: String, traderDataService: any TraderDataServiceProtocol) -> String? {
        guard let trader = traderDataService.traders.first(where: { $0.username == username }) else {
            return nil
        }
        return trader.id.uuidString
    }

    /// Gets watchlist IDs for logging (business logic)
    func getWatchlistIds(watchlistService: any InvestorWatchlistServiceProtocol) -> [String] {
        watchlistService.watchlist.map { $0.id }
    }

    // MARK: - Saved Filters Matching

    private var savedFiltersToCheck: [FilterCombination] = []
    private var isApplyingSavedFilter = false

    /// Sets the saved filters list to check against when filters change
    func setSavedFiltersToCheck(_ savedFilters: [FilterCombination]) {
        savedFiltersToCheck = savedFilters
        // Note: checkAndUpdateAppliedFilter will be called by the View when activeFilters change
    }

    /// Checks if current filters match any saved filter combination and updates applied filter ID accordingly
    func checkAndUpdateAppliedFilter(for activeFilters: [IndividualFilterCriteria]) {
        // Find matching saved filter
        if let matchingFilter = savedFiltersToCheck.first(where: { savedFilter in
            filtersMatch(savedFilter.filters, activeFilters)
        }) {
            setAppliedFilterID(matchingFilter.id.uuidString)
        } else {
            clearAppliedFilterID()
        }
    }

    /// Compares two arrays of IndividualFilterCriteria to see if they match
    private func filtersMatch(_ filter1: [IndividualFilterCriteria], _ filter2: [IndividualFilterCriteria]) -> Bool {
        guard filter1.count == filter2.count else { return false }
        // Check if all filters in filter1 exist in filter2
        return filter1.allSatisfy { filter1Item in
            filter2.contains { $0 == filter1Item }
        }
    }

    /// Handles adding a filter and clears applied filter ID, then checks for matches
    func handleAddFilter(_ filter: IndividualFilterCriteria, to activeFilters: inout [IndividualFilterCriteria]) {
        // Remove any existing filter of the same type before adding the new one
        activeFilters.removeAll { $0.type == filter.type }
        activeFilters.append(filter)

        // Clear applied filter ID if not applying a saved filter
        if !isApplyingSavedFilter {
            clearAppliedFilterID()
            // Check if current filters match any saved filter combination
            checkAndUpdateAppliedFilter(for: activeFilters)
        }
    }

    /// Handles removing a filter and clears applied filter ID if no filters remain, then checks for matches
    func handleRemoveFilter(_ filterType: IndividualFilterCriteria.FilterType, from activeFilters: inout [IndividualFilterCriteria]) {
        activeFilters.removeAll { $0.type == filterType }

        if !isApplyingSavedFilter {
            if activeFilters.isEmpty {
                clearAppliedFilterID()
            } else {
                // Check if current filters match any saved filter combination
                checkAndUpdateAppliedFilter(for: activeFilters)
            }
        }
    }

    /// Clears all active filters
    func clearAllFilters(_ activeFilters: inout [IndividualFilterCriteria]) {
        activeFilters.removeAll()
        clearAppliedFilterID()
    }

    /// Applies a saved filter and sets the applied filter ID
    func applySavedFilter(_ savedFilter: FilterCombination, to activeFilters: inout [IndividualFilterCriteria]) {
        isApplyingSavedFilter = true
        activeFilters = savedFilter.filters
        setAppliedFilterID(savedFilter.id.uuidString)
        isApplyingSavedFilter = false
    }

    // MARK: - Data Filtering

    func filteredTraders(by filters: [IndividualFilterCriteria], searchQuery: String = "") -> [MockTrader] {
        var filtered = allTraders

        // Apply search query filter if provided
        if !searchQuery.isEmpty {
            filtered = filtered.filter { trader in
                trader.username.localizedCaseInsensitiveContains(searchQuery) ||
                trader.name.localizedCaseInsensitiveContains(searchQuery) ||
                trader.specialization.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        // Apply additional filters if provided
        if !filters.isEmpty {
            let combination = FilterCombination(name: "Live Filter", filters: filters)
            filtered = filtered.filter { $0.matchesFilterCombination(combination) }
        }

        return filtered
    }
}
