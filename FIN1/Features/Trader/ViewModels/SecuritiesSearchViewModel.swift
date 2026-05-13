import Combine
import SwiftUI

// MARK: - Market Data Model
extension SecuritiesSearchViewModel {
    struct MarketData {
        let price: String
        let change: String
        let time: String
        let market: String
    }
}

// MARK: - ViewModel
@MainActor
final class SecuritiesSearchViewModel: ObservableObject {
    @Published var wknIsin: String = ""

    // Delegate to coordinator for search-related properties
    private let coordinator: any SecuritiesSearchCoordinatorProtocol

    // MARK: - DRY Property Delegation

    private var isApplyingSavedFilter = false

    private func delegateProperty<T>(
        _ setter: @escaping (T) -> Void,
        _ newValue: T,
        debugName: String? = nil
    ) {
        if let debugName = debugName {
            print("🔍 DEBUG: SecuritiesSearchViewModel.\(debugName) setter called with '\(newValue)'")
        }

        // Clear applied filter ID if user manually changes a filter (not during saved filter application)
        if !self.isApplyingSavedFilter && self.appliedFilterID != nil {
            self.appliedFilterID = nil
        }

        setter(newValue)
        objectWillChange.send()

        // Check if current filters match any saved filter combination after change
        if !self.isApplyingSavedFilter {
            self.checkAndUpdateAppliedFilter()
        }
    }

    // Computed properties that delegate to coordinator
    var category: String {
        get { self.coordinator.category }
        set { self.delegateProperty({ self.coordinator.category = $0 }, newValue, debugName: "category") }
    }

    var underlyingAsset: String {
        get { self.coordinator.underlyingAsset }
        set { self.delegateProperty({ self.coordinator.underlyingAsset = $0 }, newValue, debugName: "underlyingAsset") }
    }

    var direction: SecuritiesSearchView.Direction {
        get { self.coordinator.direction }
        set { self.delegateProperty({ self.coordinator.direction = $0 }, newValue, debugName: "direction") }
    }

    var strikePriceGap: String? {
        get { self.coordinator.strikePriceGap }
        set { self.delegateProperty({ self.coordinator.strikePriceGap = $0 }, newValue) }
    }

    var remainingTerm: String? {
        get { self.coordinator.remainingTerm }
        set { self.delegateProperty({ self.coordinator.remainingTerm = $0 }, newValue) }
    }

    var issuer: String? {
        get { self.coordinator.issuer }
        set { self.delegateProperty({ self.coordinator.issuer = $0 }, newValue) }
    }

    var omega: String? {
        get { self.coordinator.omega }
        set { self.delegateProperty({ self.coordinator.omega = $0 }, newValue) }
    }

    var activeSheet: SecuritiesSearchView.ActiveSheet? {
        get { self.coordinator.activeSheet }
        set { self.delegateProperty({ self.coordinator.activeSheet = $0 }, newValue) }
    }

    var searchResults: [SearchResult] {
        self.coordinator.searchResults
    }

    // Removed warrantDetailsViewModel - ViewModels should be managed by Views, not Services

    private nonisolated(unsafe) var cancellables = Set<AnyCancellable>()

    init(coordinator: any SecuritiesSearchCoordinatorProtocol) {
        self.coordinator = coordinator
        self.setupBindings()
    }

    deinit {
        // Clean up Combine subscriptions to prevent retain cycles
        cancellables.removeAll()
        print("🧹 SecuritiesSearchViewModel deallocated")
    }

    private func setupBindings() {
        // Listen to coordinator's search results changes and trigger ViewModel updates
        self.coordinator.searchResultsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🔍 DEBUG: SecuritiesSearchViewModel received search results update")
                self?.objectWillChange.send()
            }
            .store(in: &self.cancellables)
    }

    func performSearch() {
        self.coordinator.performSearch()
        objectWillChange.send()
    }

    // MARK: - Delegation Methods

    func getFilterDescription() -> String {
        self.coordinator.getFilterDescription()
    }

    func getUnderlyingAssetSubtitle() -> String {
        self.coordinator.getUnderlyingAssetSubtitle()
    }

    func getUnderlyingAssetMarketData() -> SecuritiesSearchViewModel.MarketData {
        self.coordinator.getUnderlyingAssetMarketData()
    }

    // MARK: - Saved Filters Management

    @Published private var appliedFilterID: String?
    private var savedFiltersToCheck: [SecuritiesFilterCombination] = []

    /// Sets the saved filters list to check against when filters change
    func setSavedFiltersToCheck(_ savedFilters: [SecuritiesFilterCombination]) {
        self.savedFiltersToCheck = savedFilters
        self.checkAndUpdateAppliedFilter()
    }

    /// Checks if current filters match any saved filter combination and updates appliedFilterID accordingly
    private func checkAndUpdateAppliedFilter() {
        let currentFilters = self.getCurrentFilters()

        // Find matching saved filter
        if let matchingFilter = savedFiltersToCheck.first(where: { savedFilter in
            filtersMatch(savedFilter.filters, currentFilters)
        }) {
            self.appliedFilterID = matchingFilter.id.uuidString
        } else {
            self.appliedFilterID = nil
        }
    }

    /// Compares two SearchFilters to see if they match
    private func filtersMatch(_ filter1: SearchFilters, _ filter2: SearchFilters) -> Bool {
        return filter1.category == filter2.category &&
            filter1.underlyingAsset == filter2.underlyingAsset &&
            filter1.direction == filter2.direction &&
            filter1.strikePriceGap == filter2.strikePriceGap &&
            filter1.remainingTerm == filter2.remainingTerm &&
            filter1.issuer == filter2.issuer &&
            filter1.omega == filter2.omega
    }

    /// Gets the current filter combination from the coordinator
    func getCurrentFilters() -> SearchFilters {
        SearchFilters(
            category: self.coordinator.category,
            underlyingAsset: self.coordinator.underlyingAsset,
            direction: self.coordinator.direction,
            strikePriceGap: self.coordinator.strikePriceGap,
            remainingTerm: self.coordinator.remainingTerm,
            issuer: self.coordinator.issuer,
            omega: self.coordinator.omega
        )
    }

    /// Applies a saved filter combination to the current search
    func applySavedFilter(_ savedFilter: SecuritiesFilterCombination) {
        self.isApplyingSavedFilter = true
        self.coordinator.category = savedFilter.filters.category
        self.coordinator.underlyingAsset = savedFilter.filters.underlyingAsset
        self.coordinator.direction = savedFilter.filters.direction
        self.coordinator.strikePriceGap = savedFilter.filters.strikePriceGap
        self.coordinator.remainingTerm = savedFilter.filters.remainingTerm
        self.coordinator.issuer = savedFilter.filters.issuer
        self.coordinator.omega = savedFilter.filters.omega
        self.appliedFilterID = savedFilter.id.uuidString
        self.isApplyingSavedFilter = false
        objectWillChange.send()
        // Trigger search after applying filters
        self.performSearch()
    }

    /// Gets the currently applied filter ID
    func getAppliedFilterID() -> String? {
        self.appliedFilterID
    }

    /// Clears the applied filter ID
    func clearAppliedFilterID() {
        self.appliedFilterID = nil
    }

    /// Checks if there are active filters (beyond defaults)
    func hasActiveFilters() -> Bool {
        let filters = self.getCurrentFilters()
        return filters.strikePriceGap != nil ||
            filters.remainingTerm != nil ||
            filters.issuer != nil ||
            filters.omega != nil ||
            filters.category != "Warrant" ||
            filters.underlyingAsset != "DAX" ||
            filters.direction != .call
    }
}
