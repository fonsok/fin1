import Combine
@testable import FIN1
import XCTest

@MainActor
final class InvestorDiscoveryViewModelTests: XCTestCase {
    // MARK: - Mocks
    final class MockPersistence: FilterPersistenceRepositoryProtocol {
        private(set) var appliedId: String?
        private(set) var clearCalls = 0
        private(set) var setCalls = 0

        func getAppliedFilterID() -> String? { self.appliedId }
        func setAppliedFilterID(_ filterID: String) { self.appliedId = filterID; self.setCalls += 1 }
        func clearAppliedFilterID() { self.appliedId = nil; self.clearCalls += 1 }
    }

    /// Aligned with `TraderDataService`: `@Published` for `ObservableObject`, `@unchecked Sendable` for the protocol.
    final class MockTraderService: TraderDataServiceProtocol, @unchecked Sendable {
        @Published var traders: [MockTrader]
        @Published var filteredTraders: [MockTrader] = []
        @Published var searchText: String = ""
        @Published var selectedRiskClass: RiskClass?
        @Published var selectedSpecialization: String?
        @Published var selectedSortOption: TraderSortOption = .name
        @Published var isLoading: Bool = false
        @Published var errorMessage: String?

        init(traders: [MockTrader]) { self.traders = traders }

        // MARK: - Protocol stubs (not used by VM)
        func loadTraderData() {}
        func refreshTraderData() {}
        func addTrader(_ trader: MockTrader) { self.traders.append(trader) }
        func updateTrader(_ trader: MockTrader) {}
        func removeTrader(_ trader: MockTrader) { self.traders.removeAll { $0.id == trader.id } }
        func performSearch() {}
        func filterByRiskClass(_ riskClass: RiskClass?) {}
        func filterBySpecialization(_ specialization: String?) {}
        func sortBy(_ option: TraderSortOption) {}
        func resetFilters() {}
        func getTrader(by id: String) -> MockTrader? { self.traders.first { $0.id.uuidString == id } }
        func getTradersByRiskClass(_ riskClass: RiskClass) -> [MockTrader] { self.traders }
        func getTradersBySpecialization(_ specialization: String) -> [MockTrader] { self.traders }
        func getTopPerformers(limit: Int) -> [MockTrader] { Array(self.traders.prefix(limit)) }
    }

    // MARK: - Helpers
    private func makeTrader(username: String, name: String? = nil, specialization: String = "Tech") -> MockTrader {
        return MockTrader(
            name: name ?? username,
            username: username,
            specialization: specialization,
            experienceYears: 3,
            isVerified: true,
            performance: 10,
            totalTrades: 10,
            winRate: 50,
            averageReturn: 5,
            totalReturn: 10,
            riskLevel: .medium,
            recentTrades: [],
            lastNTrades: 10,
            successfulTradesInLastN: 5,
            averageReturnLastNTrades: 5,
            consecutiveWinningTrades: 1,
            maxDrawdown: -5,
            sharpeRatio: 1.0
        )
    }

    // MARK: - Tests
    func test_loadTraders_populatesFromService() {
        let t1 = self.makeTrader(username: "alice")
        let service = MockTraderService(traders: [t1])
        let persistence = MockPersistence()
        let vm = InvestorDiscoveryViewModel(traderDataService: service, filterPersistence: persistence)

        vm.loadTraders()

        XCTAssertEqual(vm.allTraders.count, 1)
        XCTAssertEqual(vm.allTraders.first?.username, "alice")
    }

    func test_handleSearchChange_debounceUpdatesQuery_andClearsAppliedFilterWhenNonEmpty() {
        let t1 = self.makeTrader(username: "alice")
        let service = MockTraderService(traders: [t1])
        let persistence = MockPersistence()
        let vm = InvestorDiscoveryViewModel(traderDataService: service, filterPersistence: persistence)

        let exp = expectation(description: "debounced")
        vm.handleSearchChange(" alice ")

        // Wait >300ms debounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertEqual(vm.searchQuery, "alice")
            XCTAssertEqual(persistence.clearCalls, 1)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func test_clearSearch_resetsQuery_andClearsAppliedFilter() {
        let service = MockTraderService(traders: [makeTrader(username: "alice")])
        let persistence = MockPersistence()
        let vm = InvestorDiscoveryViewModel(traderDataService: service, filterPersistence: persistence)

        vm.searchQuery = "foo"
        vm.clearSearch()

        XCTAssertEqual(vm.searchQuery, "")
        XCTAssertEqual(persistence.clearCalls, 1)
    }

    func test_applySavedFilter_setsFilters_andPersistsID() {
        let service = MockTraderService(traders: [])
        let persistence = MockPersistence()
        let vm = InvestorDiscoveryViewModel(traderDataService: service, filterPersistence: persistence)

        var active: [IndividualFilterCriteria] = []
        let filter = IndividualFilterCriteria(type: .returnRate, returnPercentageOption: .greaterThan20)
        let combo = FilterCombination(name: "Top20", filters: [filter])

        vm.applySavedFilter(combo, to: &active)

        XCTAssertEqual(active, [filter])
        XCTAssertEqual(persistence.setCalls, 1)
        XCTAssertEqual(persistence.getAppliedFilterID(), combo.id.uuidString)
    }

    func test_filteredTraders_respectsSearchQuery() {
        let a = self.makeTrader(username: "alice", name: "Alice", specialization: "Tech")
        let b = self.makeTrader(username: "bob", name: "Bob", specialization: "Crypto")
        let service = MockTraderService(traders: [a, b])
        let vm = InvestorDiscoveryViewModel(traderDataService: service, filterPersistence: MockPersistence())
        vm.loadTraders()

        let result1 = vm.filteredTraders(by: [], searchQuery: "ali")
        XCTAssertEqual(result1.map { $0.username }, ["alice"])

        let result2 = vm.filteredTraders(by: [], searchQuery: "crypto")
        XCTAssertEqual(result2.map { $0.username }, ["bob"])
    }
}


