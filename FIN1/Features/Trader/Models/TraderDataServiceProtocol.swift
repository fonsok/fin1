import Combine
import Foundation
import SwiftUI

// MARK: - Trader Data Service Protocol
/// Defines the contract for trader data operations and management
protocol TraderDataServiceProtocol: ObservableObject, Sendable {
    /// Full catalog: mock seed (hydrated) + server-only traders (Discover / search).
    var traders: [InvestorTrader] { get }
    /// Mock seed traders with demo metrics — Dashboard „Top Recent Trades“ (performance sort).
    var dashboardTraders: [InvestorTrader] { get }
    var filteredTraders: [InvestorTrader] { get }
    var searchText: String { get set }
    var selectedRiskClass: RiskClass? { get set }
    var selectedSpecialization: String? { get set }
    var selectedSortOption: TraderSortOption { get set }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Trader Data Management
    func loadTraderData()
    func refreshTraderData()
    /// Merges `discoverTraders` into mock catalog + appends server-only traders.
    func refreshTraderCatalog() async
    /// Back-compat alias — calls `refreshTraderCatalog()`.
    func refreshParseUserIds() async
    func addTrader(_ trader: InvestorTrader)
    func updateTrader(_ trader: InvestorTrader)
    func removeTrader(_ trader: InvestorTrader)

    // MARK: - Search and Filtering
    func performSearch()
    func filterByRiskClass(_ riskClass: RiskClass?)
    func filterBySpecialization(_ specialization: String?)
    func sortBy(_ option: TraderSortOption)
    func resetFilters()

    // MARK: - Trader Queries
    func getTrader(by id: String) -> InvestorTrader?
    func getTradersByRiskClass(_ riskClass: RiskClass) -> [InvestorTrader]
    func getTradersBySpecialization(_ specialization: String) -> [InvestorTrader]
    func getTopPerformers(limit: Int) -> [InvestorTrader]
}

// MARK: - Trader Data Service Implementation
/// Handles trader data operations, search, filtering, and sorting
final class TraderDataService: TraderDataServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    static let shared = TraderDataService()

    @Published var traders: [InvestorTrader] = []
    @Published var filteredTraders: [InvestorTrader] = []

    var dashboardTraders: [InvestorTrader] {
        self.allTraders.filter(\.isFromMockCatalog)
    }
    @Published var searchText: String = ""
    @Published var selectedRiskClass: RiskClass?
    @Published var selectedSpecialization: String?
    @Published var selectedSortOption: TraderSortOption = .name
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var allTraders: [InvestorTrader] = []
    private var parseAPIClient: (any ParseAPIClientProtocol)?

    init() {
        self.loadMockData()
        self.performSearch()
    }

    func configure(parseAPIClient: any ParseAPIClientProtocol) {
        self.parseAPIClient = parseAPIClient
    }

    // MARK: - ServiceLifecycle
    func start() {
        Task { @MainActor in
            await self.refreshTraderCatalog()
        }
    }
    func stop() { /* noop */ }
    func reset() { self.traders.removeAll(); self.filteredTraders.removeAll(); self.allTraders.removeAll() }

    // MARK: - Trader Data Management

    func loadTraderData() {
        self.isLoading = true

        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoading = false
            self.performSearch()
        }
    }

    func refreshTraderData() {
        self.isLoading = true
        Task { @MainActor in
            await self.refreshTraderCatalog()
            self.isLoading = false
            self.performSearch()
        }
    }

    func refreshTraderCatalog() async {
        guard let client = parseAPIClient else { return }
        self.isLoading = true
        defer { self.isLoading = false }
        do {
            let serverRows = try await TraderDiscoveryAPIService(apiClient: client).fetchAllDiscoverableTraders()
            let merged = TraderCatalogMerge.merge(mockCatalog: mockTraders, serverRows: serverRows)
            self.allTraders = merged
            self.traders = merged
            self.performSearch()
            let serverOnlyCount = merged.filter { !$0.isFromMockCatalog }.count
            print("✅ TraderDataService: catalog merged — total \(merged.count), server-only \(serverOnlyCount)")
        } catch {
            print("⚠️ TraderDataService: refreshTraderCatalog failed: \(error.localizedDescription)")
        }
    }

    func refreshParseUserIds() async {
        await self.refreshTraderCatalog()
    }

    func addTrader(_ trader: InvestorTrader) {
        if !self.traders.contains(where: { $0.id == trader.id }) {
            self.traders.append(trader)
            self.allTraders.append(trader)
            self.performSearch()
        }
    }

    func updateTrader(_ trader: InvestorTrader) {
        if let index = traders.firstIndex(where: { $0.id == trader.id }) {
            self.traders[index] = trader
            if let allIndex = allTraders.firstIndex(where: { $0.id == trader.id }) {
                self.allTraders[allIndex] = trader
            }
            self.performSearch()
        }
    }

    func removeTrader(_ trader: InvestorTrader) {
        self.traders.removeAll { $0.id == trader.id }
        self.allTraders.removeAll { $0.id == trader.id }
        self.performSearch()
    }

    // MARK: - Search and Filtering

    func performSearch() {
        var filtered = self.allTraders

        // Apply search filter
        if !self.searchText.isEmpty {
            filtered = filtered.filter { trader in
                trader.name.localizedCaseInsensitiveContains(self.searchText) ||
                    trader.specialization.localizedCaseInsensitiveContains(self.searchText)
            }
        }

        // Apply risk class filter
        if let selectedRiskClass = selectedRiskClass {
            // Approximate mapping from RiskLevel to RiskClass buckets
            func riskLevelToClass(_ level: TraderRiskLevel) -> RiskClass {
                switch level {
                case .low: return .riskClass2
                case .medium: return .riskClass4
                case .high: return .riskClass6
                }
            }
            filtered = filtered.filter { riskLevelToClass($0.riskLevel) == selectedRiskClass }
        }

        // Apply specialization filter
        if let selectedSpecialization = selectedSpecialization {
            filtered = filtered.filter { $0.specialization == selectedSpecialization }
        }

        // Apply sorting
        filtered = self.sortTraders(filtered, by: self.selectedSortOption)

        self.filteredTraders = filtered
    }

    func filterByRiskClass(_ riskClass: RiskClass?) {
        self.selectedRiskClass = riskClass
        self.performSearch()
    }

    func filterBySpecialization(_ specialization: String?) {
        self.selectedSpecialization = specialization
        self.performSearch()
    }

    func sortBy(_ option: TraderSortOption) {
        self.selectedSortOption = option
        self.performSearch()
    }

    func resetFilters() {
        self.searchText = ""
        self.selectedRiskClass = nil
        self.selectedSpecialization = nil
        self.selectedSortOption = .name
        self.performSearch()
    }

    // MARK: - Trader Queries

    func getTrader(by id: String) -> InvestorTrader? {
        let key = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return self.allTraders.first {
            $0.catalogId == id
                || $0.parseUserId == id
                || $0.backendTraderId == id
                || $0.username.lowercased() == key
        }
    }

    func getTradersByRiskClass(_ riskClass: RiskClass) -> [InvestorTrader] {
        func riskLevelToClass(_ level: TraderRiskLevel) -> RiskClass {
            switch level {
            case .low: return .riskClass2
            case .medium: return .riskClass4
            case .high: return .riskClass6
            }
        }
        return self.allTraders.filter { riskLevelToClass($0.riskLevel) == riskClass }
    }

    func getTradersBySpecialization(_ specialization: String) -> [InvestorTrader] {
        return self.allTraders.filter { $0.specialization == specialization }
    }

    func getTopPerformers(limit: Int) -> [InvestorTrader] {
        return self.allTraders
            .sorted { $0.performance > $1.performance }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Private Methods

    private func sortTraders(_ traders: [InvestorTrader], by option: TraderSortOption) -> [InvestorTrader] {
        switch option {
        case .name:
            return traders.sorted { $0.name < $1.name }
        case .performance:
            return traders.sorted { $0.performance > $1.performance }
        case .riskClass:
            func score(_ level: TraderRiskLevel) -> Int { level == .low ? 1 : (level == .medium ? 2 : 3) }
            return traders.sorted { score($0.riskLevel) < score($1.riskLevel) }
        case .experience:
            return traders.sorted { $0.experienceYears > $1.experienceYears }
        case .totalInvestors:
            return traders.sorted { $0.totalTrades > $1.totalTrades }
        case .minimumInvestment:
            return traders
        }
    }

    private func loadMockData() {
        // Use the full mockTraders array for better filter testing
        // Includes 7 traders with varied performance metrics
        self.allTraders = mockTraders.map { InvestorTrader(mock: $0, isFromMockCatalog: true) }
        self.traders = self.allTraders
    }
}

// MARK: - Supporting Types

enum TraderSortOption: String, CaseIterable {
    case name = "Name"
    case performance = "Performance"
    case riskClass = "Risk Class"
    case experience = "Experience"
    case totalInvestors = "Total Investors"
    case minimumInvestment = "Min Investment"
}
