import SwiftUI
import Combine

// MARK: - Search Coordinator Protocol
@MainActor
protocol SecuritiesSearchCoordinatorProtocol: ObservableObject {
    var activeSheet: SecuritiesSearchView.ActiveSheet? { get set }
    var searchResults: [SearchResult] { get }
    var searchResultsPublisher: AnyPublisher<[SearchResult], Never> { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // Filter properties
    var category: String { get set }
    var underlyingAsset: String { get set }
    var direction: SecuritiesSearchView.Direction { get set }
    var strikePriceGap: String? { get set }
    var remainingTerm: String? { get set }
    var issuer: String? { get set }
    var omega: String? { get set }
    // Removed warrantDetailsViewModel - ViewModels should be managed by Views, not Services

    func presentSheet(_ sheet: SecuritiesSearchView.ActiveSheet)
    func dismissSheet()
    func performSearch()
    func getFilterDescription() -> String
    func getUnderlyingAssetSubtitle() -> String
    func getUnderlyingAssetMarketData() -> SecuritiesSearchViewModel.MarketData
}

// MARK: - Search Coordinator Implementation
@MainActor
final class SecuritiesSearchCoordinator: SecuritiesSearchCoordinatorProtocol {
    @Published var activeSheet: SecuritiesSearchView.ActiveSheet?
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let searchService: any SecuritiesSearchServiceProtocol
    private let filterManager: any SearchFilterServiceProtocol
    private nonisolated(unsafe) var cancellables = Set<AnyCancellable>()

    init(searchService: any SecuritiesSearchServiceProtocol, filterManager: any SearchFilterServiceProtocol) {
        self.searchService = searchService
        self.filterManager = filterManager

        setupBindings()
    }

    deinit {
        cancellables.removeAll()
        print("🧹 SecuritiesSearchCoordinator deallocated")
    }

    // MARK: - Public Interface

    var searchResultsPublisher: AnyPublisher<[SearchResult], Never> {
        $searchResults.eraseToAnyPublisher()
    }

    func presentSheet(_ sheet: SecuritiesSearchView.ActiveSheet) {
        activeSheet = sheet
    }

    func dismissSheet() {
        activeSheet = nil
    }

    func performSearch() {
        Task {
            await executeSearch()
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Listen to filter changes and trigger search
        filterManager.filtersPublisher
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.performSearch()
            }
            .store(in: &cancellables)

        // Listen to search service results
        searchService.searchResultsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                print("🔍 DEBUG: SecuritiesSearchCoordinator received \(results.count) results")
                if let firstResult = results.first {
                    print("🔍 DEBUG: First result direction: \(firstResult.direction ?? "nil")")
                }
                self?.searchResults = results
            }
            .store(in: &cancellables)

        searchService.isLoadingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                self?.isLoading = loading
            }
            .store(in: &cancellables)

        searchService.errorMessagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error
            }
            .store(in: &cancellables)
    }

    private func executeSearch() async {
        let filters = filterManager.getCurrentFilters()
        print("🔍 DEBUG: SecuritiesSearchCoordinator.executeSearch() called")
        print("🔍 DEBUG: filters.underlyingAsset = '\(filters.underlyingAsset)'")
        print("🔍 DEBUG: filters.direction = \(filters.direction)")
        print("🔍 DEBUG: filters.direction.rawValue = \(filters.direction.rawValue)")
        await searchService.performSearch(with: filters)
    }
}

// MARK: - Filter Access
extension SecuritiesSearchCoordinator {
    var category: String {
        get { filterManager.category }
        set {
            filterManager.category = newValue
            objectWillChange.send()
        }
    }

    var underlyingAsset: String {
        get { filterManager.underlyingAsset }
        set {
            filterManager.underlyingAsset = newValue
            objectWillChange.send()
            // Trigger immediate search for underlying asset changes
            Task {
                await executeSearch()
            }
        }
    }

    var direction: SecuritiesSearchView.Direction {
        get { filterManager.direction }
        set {
            filterManager.direction = newValue
            objectWillChange.send()
        }
    }

    var strikePriceGap: String? {
        get { filterManager.strikePriceGap }
        set {
            filterManager.strikePriceGap = newValue
            objectWillChange.send()
        }
    }

    var remainingTerm: String? {
        get { filterManager.remainingTerm }
        set {
            filterManager.remainingTerm = newValue
            objectWillChange.send()
        }
    }

    var issuer: String? {
        get { filterManager.issuer }
        set {
            filterManager.issuer = newValue
            objectWillChange.send()
        }
    }

    var omega: String? {
        get { filterManager.omega }
        set {
            filterManager.omega = newValue
            objectWillChange.send()
        }
    }

    // Removed warrantDetailsViewModel - ViewModels should be managed by Views, not Services

    func getFilterDescription() -> String {
        filterManager.getFilterDescription()
    }

    func getUnderlyingAssetSubtitle() -> String {
        filterManager.getUnderlyingAssetSubtitle()
    }

    func getUnderlyingAssetMarketData() -> SecuritiesSearchViewModel.MarketData {
        filterManager.getUnderlyingAssetMarketData()
    }
}
