import SwiftUI
import Combine

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

    private func delegateProperty<T>(_ setter: @escaping (T) -> Void,
                                     _ newValue: T,
                                     debugName: String? = nil) {
        if let debugName = debugName {
            print("🔍 DEBUG: SecuritiesSearchViewModel.\(debugName) setter called with '\(newValue)'")
        }

        // Clear applied filter ID if user manually changes a filter (not during saved filter application)
        if !isApplyingSavedFilter && appliedFilterID != nil {
            appliedFilterID = nil
        }

        setter(newValue)
        objectWillChange.send()

        // Check if current filters match any saved filter combination after change
        if !isApplyingSavedFilter {
            checkAndUpdateAppliedFilter()
        }
    }

    // Computed properties that delegate to coordinator
    var category: String {
        get { coordinator.category }
        set { delegateProperty({ self.coordinator.category = $0 }, newValue, debugName: "category") }
    }

    var underlyingAsset: String {
        get { coordinator.underlyingAsset }
        set { delegateProperty({ self.coordinator.underlyingAsset = $0 }, newValue, debugName: "underlyingAsset") }
    }

    var direction: SecuritiesSearchView.Direction {
        get { coordinator.direction }
        set { delegateProperty({ self.coordinator.direction = $0 }, newValue, debugName: "direction") }
    }

    var strikePriceGap: String? {
        get { coordinator.strikePriceGap }
        set { delegateProperty({ self.coordinator.strikePriceGap = $0 }, newValue) }
    }

    var remainingTerm: String? {
        get { coordinator.remainingTerm }
        set { delegateProperty({ self.coordinator.remainingTerm = $0 }, newValue) }
    }

    var issuer: String? {
        get { coordinator.issuer }
        set { delegateProperty({ self.coordinator.issuer = $0 }, newValue) }
    }

    var omega: String? {
        get { coordinator.omega }
        set { delegateProperty({ self.coordinator.omega = $0 }, newValue) }
    }

    var activeSheet: SecuritiesSearchView.ActiveSheet? {
        get { coordinator.activeSheet }
        set { delegateProperty({ self.coordinator.activeSheet = $0 }, newValue) }
    }

    var searchResults: [SearchResult] {
        coordinator.searchResults
    }

    // Removed warrantDetailsViewModel - ViewModels should be managed by Views, not Services

    private var cancellables = Set<AnyCancellable>()

    init(coordinator: any SecuritiesSearchCoordinatorProtocol) {
        self.coordinator = coordinator
        setupBindings()
    }

    deinit {
        // Clean up Combine subscriptions to prevent retain cycles
        cancellables.removeAll()
        print("🧹 SecuritiesSearchViewModel deallocated")
    }

    private func setupBindings() {
        // Listen to coordinator's search results changes and trigger ViewModel updates
        coordinator.searchResultsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🔍 DEBUG: SecuritiesSearchViewModel received search results update")
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func performSearch() {
        coordinator.performSearch()
        objectWillChange.send()
    }

    // MARK: - Delegation Methods

    func getFilterDescription() -> String {
        coordinator.getFilterDescription()
    }

    func getUnderlyingAssetSubtitle() -> String {
        coordinator.getUnderlyingAssetSubtitle()
    }

    func getUnderlyingAssetMarketData() -> SecuritiesSearchViewModel.MarketData {
        coordinator.getUnderlyingAssetMarketData()
    }

    // MARK: - Saved Filters Management

    @Published private var appliedFilterID: String?
    private var savedFiltersToCheck: [SecuritiesFilterCombination] = []

    /// Sets the saved filters list to check against when filters change
    func setSavedFiltersToCheck(_ savedFilters: [SecuritiesFilterCombination]) {
        savedFiltersToCheck = savedFilters
        checkAndUpdateAppliedFilter()
    }

    /// Checks if current filters match any saved filter combination and updates appliedFilterID accordingly
    private func checkAndUpdateAppliedFilter() {
        let currentFilters = getCurrentFilters()

        // Find matching saved filter
        if let matchingFilter = savedFiltersToCheck.first(where: { savedFilter in
            filtersMatch(savedFilter.filters, currentFilters)
        }) {
            appliedFilterID = matchingFilter.id.uuidString
        } else {
            appliedFilterID = nil
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
            category: coordinator.category,
            underlyingAsset: coordinator.underlyingAsset,
            direction: coordinator.direction,
            strikePriceGap: coordinator.strikePriceGap,
            remainingTerm: coordinator.remainingTerm,
            issuer: coordinator.issuer,
            omega: coordinator.omega
        )
    }

    /// Applies a saved filter combination to the current search
    func applySavedFilter(_ savedFilter: SecuritiesFilterCombination) {
        isApplyingSavedFilter = true
        coordinator.category = savedFilter.filters.category
        coordinator.underlyingAsset = savedFilter.filters.underlyingAsset
        coordinator.direction = savedFilter.filters.direction
        coordinator.strikePriceGap = savedFilter.filters.strikePriceGap
        coordinator.remainingTerm = savedFilter.filters.remainingTerm
        coordinator.issuer = savedFilter.filters.issuer
        coordinator.omega = savedFilter.filters.omega
        appliedFilterID = savedFilter.id.uuidString
        isApplyingSavedFilter = false
        objectWillChange.send()
        // Trigger search after applying filters
        performSearch()
    }

    /// Gets the currently applied filter ID
    func getAppliedFilterID() -> String? {
        appliedFilterID
    }

    /// Clears the applied filter ID
    func clearAppliedFilterID() {
        appliedFilterID = nil
    }

    /// Checks if there are active filters (beyond defaults)
    func hasActiveFilters() -> Bool {
        let filters = getCurrentFilters()
        return filters.strikePriceGap != nil ||
               filters.remainingTerm != nil ||
               filters.issuer != nil ||
               filters.omega != nil ||
               filters.category != "Warrant" ||
               filters.underlyingAsset != "DAX" ||
               filters.direction != .call
    }
}
