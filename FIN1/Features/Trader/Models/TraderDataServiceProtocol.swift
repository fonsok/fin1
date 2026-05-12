import Foundation
import SwiftUI
import Combine

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
        loadMockData()
        performSearch()
    }

    // MARK: - ServiceLifecycle
    func start() { /* preload/mock fetch */ }
    func stop() { /* noop */ }
    func reset() { traders.removeAll(); filteredTraders.removeAll(); allTraders.removeAll() }

    // MARK: - Trader Data Management

    func loadTraderData() {
        isLoading = true

        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoading = false
            self.performSearch()
        }
    }

    func refreshTraderData() {
        isLoading = true

        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            self.performSearch()
        }
    }

    func addTrader(_ trader: MockTrader) {
        if !traders.contains(where: { $0.id == trader.id }) {
            traders.append(trader)
            allTraders.append(trader)
            performSearch()
        }
    }

    func updateTrader(_ trader: MockTrader) {
        if let index = traders.firstIndex(where: { $0.id == trader.id }) {
            traders[index] = trader
            if let allIndex = allTraders.firstIndex(where: { $0.id == trader.id }) {
                allTraders[allIndex] = trader
            }
            performSearch()
        }
    }

    func removeTrader(_ trader: MockTrader) {
        traders.removeAll { $0.id == trader.id }
        allTraders.removeAll { $0.id == trader.id }
        performSearch()
    }

    // MARK: - Search and Filtering

    func performSearch() {
        var filtered = allTraders

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { trader in
                trader.name.localizedCaseInsensitiveContains(searchText) ||
                trader.specialization.localizedCaseInsensitiveContains(searchText)
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
        filtered = sortTraders(filtered, by: selectedSortOption)

        filteredTraders = filtered
    }

    func filterByRiskClass(_ riskClass: RiskClass?) {
        selectedRiskClass = riskClass
        performSearch()
    }

    func filterBySpecialization(_ specialization: String?) {
        selectedSpecialization = specialization
        performSearch()
    }

    func sortBy(_ option: TraderSortOption) {
        selectedSortOption = option
        performSearch()
    }

    func resetFilters() {
        searchText = ""
        selectedRiskClass = nil
        selectedSpecialization = nil
        selectedSortOption = .name
        performSearch()
    }

    // MARK: - Trader Queries

    func getTrader(by id: String) -> MockTrader? {
        return allTraders.first { $0.id.uuidString == id }
    }

    func getTradersByRiskClass(_ riskClass: RiskClass) -> [MockTrader] {
        func riskLevelToClass(_ level: MockTrader.RiskLevel) -> RiskClass {
            switch level {
            case .low: return .riskClass2
            case .medium: return .riskClass4
            case .high: return .riskClass6
            }
        }
        return allTraders.filter { riskLevelToClass($0.riskLevel) == riskClass }
    }

    func getTradersBySpecialization(_ specialization: String) -> [MockTrader] {
        return allTraders.filter { $0.specialization == specialization }
    }

    func getTopPerformers(limit: Int) -> [MockTrader] {
        return allTraders
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
        allTraders = mockTraders
        traders = allTraders
    }

    private func createTechTrader() -> MockTrader {
        return MockTrader(
            name: "trader1",
            username: "trader1",
            specialization: "Tech",
            experienceYears: 5,
            isVerified: true,
            performance: 12.4 * 10,
            totalTrades: 120,
            winRate: 68.0,
            averageReturn: 5.2 * 10,
            totalReturn: 12.4 * 10,
            riskLevel: .medium,
            recentTrades: generateMockTradePerformance(count: 20, successRate: 0.68, avgReturn: 5.2 * 10),
            lastNTrades: 20,
            successfulTradesInLastN: 14,
            averageReturnLastNTrades: 5.2 * 10,
            consecutiveWinningTrades: 3,
            maxDrawdown: -6.5,
            sharpeRatio: 1.1
        )
    }

    private func createCryptoTrader() -> MockTrader {
        return MockTrader(
            name: "trader2",
            username: "trader2",
            specialization: "Crypto",
            experienceYears: 3,
            isVerified: true,
            performance: 8.9 * 10,
            totalTrades: 90,
            winRate: 62.0,
            averageReturn: 3.8 * 10,
            totalReturn: 8.9 * 10,
            riskLevel: .high,
            recentTrades: generateMockTradePerformance(count: 20, successRate: 0.62, avgReturn: 3.8 * 10),
            lastNTrades: 20,
            successfulTradesInLastN: 12,
            averageReturnLastNTrades: 3.8 * 10,
            consecutiveWinningTrades: 2,
            maxDrawdown: -12.0,
            sharpeRatio: 0.8
        )
    }

    private func createValueTrader() -> MockTrader {
        return MockTrader(
            name: "trader3",
            username: "trader3",
            specialization: "Value",
            experienceYears: 7,
            isVerified: false,
            performance: 15.1 * 10,
            totalTrades: 150,
            winRate: 70.0,
            averageReturn: 4.5 * 10,
            totalReturn: 15.1 * 10,
            riskLevel: .low,
            recentTrades: generateMockTradePerformance(count: 20, successRate: 0.70, avgReturn: 4.5 * 10),
            lastNTrades: 20,
            successfulTradesInLastN: 14,
            averageReturnLastNTrades: 4.5 * 10,
            consecutiveWinningTrades: 4,
            maxDrawdown: -4.2,
            sharpeRatio: 1.3
        )
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
