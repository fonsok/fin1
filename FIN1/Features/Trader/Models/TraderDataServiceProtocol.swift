import Combine
import Foundation
import SwiftUI

// MARK: - Trader Data Service Protocol
/// Defines the contract for trader data operations and management
protocol TraderDataServiceProtocol: ObservableObject, Sendable {
    var traders: [MockTrader] { get }
    var filteredTraders: [MockTrader] { get }
    var searchText: String { get set }
    var selectedRiskClass: RiskClass? { get set }
    var selectedSpecialization: String? { get set }
    var selectedSortOption: TraderSortOption { get set }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Trader Data Management
    func loadTraderData()
    func refreshTraderData()
    func addTrader(_ trader: MockTrader)
    func updateTrader(_ trader: MockTrader)
    func removeTrader(_ trader: MockTrader)

    // MARK: - Search and Filtering
    func performSearch()
    func filterByRiskClass(_ riskClass: RiskClass?)
    func filterBySpecialization(_ specialization: String?)
    func sortBy(_ option: TraderSortOption)
    func resetFilters()

    // MARK: - Trader Queries
    func getTrader(by id: String) -> MockTrader?
    func getTradersByRiskClass(_ riskClass: RiskClass) -> [MockTrader]
    func getTradersBySpecialization(_ specialization: String) -> [MockTrader]
    func getTopPerformers(limit: Int) -> [MockTrader]
}

// MARK: - Trader Data Service Implementation
/// Handles trader data operations, search, filtering, and sorting
final class TraderDataService: TraderDataServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    static let shared = TraderDataService()

    @Published var traders: [MockTrader] = []
    @Published var filteredTraders: [MockTrader] = []
    @Published var searchText: String = ""
    @Published var selectedRiskClass: RiskClass?
    @Published var selectedSpecialization: String?
    @Published var selectedSortOption: TraderSortOption = .name
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var allTraders: [MockTrader] = []

    init() {
        self.loadMockData()
        self.performSearch()
    }

    // MARK: - ServiceLifecycle
    func start() { /* preload/mock fetch */ }
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

        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            self.performSearch()
        }
    }

    func addTrader(_ trader: MockTrader) {
        if !self.traders.contains(where: { $0.id == trader.id }) {
            self.traders.append(trader)
            self.allTraders.append(trader)
            self.performSearch()
        }
    }

    func updateTrader(_ trader: MockTrader) {
        if let index = traders.firstIndex(where: { $0.id == trader.id }) {
            self.traders[index] = trader
            if let allIndex = allTraders.firstIndex(where: { $0.id == trader.id }) {
                self.allTraders[allIndex] = trader
            }
            self.performSearch()
        }
    }

    func removeTrader(_ trader: MockTrader) {
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
            func riskLevelToClass(_ level: MockTrader.RiskLevel) -> RiskClass {
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

    func getTrader(by id: String) -> MockTrader? {
        return self.allTraders.first { $0.id.uuidString == id }
    }

    func getTradersByRiskClass(_ riskClass: RiskClass) -> [MockTrader] {
        func riskLevelToClass(_ level: MockTrader.RiskLevel) -> RiskClass {
            switch level {
            case .low: return .riskClass2
            case .medium: return .riskClass4
            case .high: return .riskClass6
            }
        }
        return self.allTraders.filter { riskLevelToClass($0.riskLevel) == riskClass }
    }

    func getTradersBySpecialization(_ specialization: String) -> [MockTrader] {
        return self.allTraders.filter { $0.specialization == specialization }
    }

    func getTopPerformers(limit: Int) -> [MockTrader] {
        return self.allTraders
            .sorted { $0.performance > $1.performance }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Private Methods

    private func sortTraders(_ traders: [MockTrader], by option: TraderSortOption) -> [MockTrader] {
        switch option {
        case .name:
            return traders.sorted { $0.name < $1.name }
        case .performance:
            return traders.sorted { $0.performance > $1.performance }
        case .riskClass:
            func score(_ level: MockTrader.RiskLevel) -> Int { level == .low ? 1 : (level == .medium ? 2 : 3) }
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
        self.allTraders = mockTraders
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
