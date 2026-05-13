import Combine
import SwiftUI

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

        self.setupBindings()
    }

    deinit {
        cancellables.removeAll()
        print("🧹 SecuritiesSearchCoordinator deallocated")
    }

    // MARK: - Public Interface

    var searchResultsPublisher: AnyPublisher<[SearchResult], Never> {
        self.$searchResults.eraseToAnyPublisher()
    }

    func presentSheet(_ sheet: SecuritiesSearchView.ActiveSheet) {
        self.activeSheet = sheet
    }

    func dismissSheet() {
        self.activeSheet = nil
    }

    func performSearch() {
        Task {
            await self.executeSearch()
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Listen to filter changes and trigger search
        self.filterManager.filtersPublisher
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.performSearch()
            }
            .store(in: &self.cancellables)

        // Listen to search service results
        self.searchService.searchResultsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                print("🔍 DEBUG: SecuritiesSearchCoordinator received \(results.count) results")
                if let firstResult = results.first {
                    print("🔍 DEBUG: First result direction: \(firstResult.direction ?? "nil")")
                }
                self?.searchResults = results
            }
            .store(in: &self.cancellables)

        self.searchService.isLoadingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                self?.isLoading = loading
            }
            .store(in: &self.cancellables)

        self.searchService.errorMessagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error
            }
            .store(in: &self.cancellables)
    }

    private func executeSearch() async {
        let filters = self.filterManager.getCurrentFilters()
        print("🔍 DEBUG: SecuritiesSearchCoordinator.executeSearch() called")
        print("🔍 DEBUG: filters.underlyingAsset = '\(filters.underlyingAsset)'")
        print("🔍 DEBUG: filters.direction = \(filters.direction)")
        print("🔍 DEBUG: filters.direction.rawValue = \(filters.direction.rawValue)")
        await self.searchService.performSearch(with: filters)
    }
}

// MARK: - Filter Access
extension SecuritiesSearchCoordinator {
    var category: String {
        get { self.filterManager.category }
        set {
            self.filterManager.category = newValue
            objectWillChange.send()
        }
    }

    var underlyingAsset: String {
        get { self.filterManager.underlyingAsset }
        set {
            self.filterManager.underlyingAsset = newValue
            objectWillChange.send()
            // Trigger immediate search for underlying asset changes
            Task {
                await self.executeSearch()
            }
        }
    }

    var direction: SecuritiesSearchView.Direction {
        get { self.filterManager.direction }
        set {
            self.filterManager.direction = newValue
            objectWillChange.send()
        }
    }

    var strikePriceGap: String? {
        get { self.filterManager.strikePriceGap }
        set {
            self.filterManager.strikePriceGap = newValue
            objectWillChange.send()
        }
    }

    var remainingTerm: String? {
        get { self.filterManager.remainingTerm }
        set {
            self.filterManager.remainingTerm = newValue
            objectWillChange.send()
        }
    }

    var issuer: String? {
        get { self.filterManager.issuer }
        set {
            self.filterManager.issuer = newValue
            objectWillChange.send()
        }
    }

    var omega: String? {
        get { self.filterManager.omega }
        set {
            self.filterManager.omega = newValue
            objectWillChange.send()
        }
    }

    // Removed warrantDetailsViewModel - ViewModels should be managed by Views, not Services

    func getFilterDescription() -> String {
        self.filterManager.getFilterDescription()
    }

    func getUnderlyingAssetSubtitle() -> String {
        self.filterManager.getUnderlyingAssetSubtitle()
    }

    func getUnderlyingAssetMarketData() -> SecuritiesSearchViewModel.MarketData {
        self.filterManager.getUnderlyingAssetMarketData()
    }
}
