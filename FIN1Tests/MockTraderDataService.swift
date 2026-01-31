import Foundation
import Combine
@testable import FIN1

// MARK: - Mock Trader Data Service
class MockTraderDataService: TraderDataServiceProtocol {
    @Published var traders: [MockTrader] = []
    @Published var filteredTraders: [MockTrader] = []
    @Published var searchText: String = ""
    @Published var selectedRiskClass: RiskClass?
    @Published var selectedSpecialization: String?
    @Published var selectedSortOption: TraderSortOption = .name
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var allTraders: [MockTrader] = []

    // MARK: - Trader Data Management
    func loadTraderData() {
        isLoading = true
        // Use app's mockTraders if available; otherwise construct a minimal set
        allTraders = mockTraders.isEmpty ? [
            MockTrader(
                name: "Test Trader 1",
                username: "trader1",
                specialization: "Options Trading",
                experienceYears: 5,
                isVerified: true,
                performance: 15.5,
                totalTrades: 100,
                winRate: 75.0,
                averageReturn: 8.2,
                totalReturn: 15000.0,
                riskLevel: .medium,
                recentTrades: [],
                lastNTrades: 10,
                successfulTradesInLastN: 8,
                averageReturnLastNTrades: 5.5,
                consecutiveWinningTrades: 3,
                maxDrawdown: 12.0,
                sharpeRatio: 1.8
            ),
            MockTrader(
                name: "Test Trader 2",
                username: "trader2",
                specialization: "Stock Trading",
                experienceYears: 3,
                isVerified: false,
                performance: 8.2,
                totalTrades: 50,
                winRate: 60.0,
                averageReturn: 4.1,
                totalReturn: 5000.0,
                riskLevel: .low,
                recentTrades: [],
                lastNTrades: 10,
                successfulTradesInLastN: 6,
                averageReturnLastNTrades: 2.8,
                consecutiveWinningTrades: 2,
                maxDrawdown: 8.0,
                sharpeRatio: 1.2
            )
        ] : mockTraders
        traders = allTraders
        isLoading = false
        performSearch()
    }

    func refreshTraderData() {
        loadTraderData()
    }

    func addTrader(_ trader: MockTrader) {
        if !allTraders.contains(where: { $0.id == trader.id }) {
            allTraders.append(trader)
            traders = allTraders
            performSearch()
        }
    }

    func updateTrader(_ trader: MockTrader) {
        if let idx = allTraders.firstIndex(where: { $0.id == trader.id }) {
            allTraders[idx] = trader
            traders = allTraders
            performSearch()
        }
    }

    func removeTrader(_ trader: MockTrader) {
        allTraders.removeAll { $0.id == trader.id }
        traders = allTraders
        performSearch()
    }

    // MARK: - Search and Filtering
    func performSearch() {
        var filtered = allTraders
        if !searchText.isEmpty {
            filtered = filtered.filter { t in
                t.name.localizedCaseInsensitiveContains(searchText) ||
                t.specialization.localizedCaseInsensitiveContains(searchText) ||
                t.username.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let rc = selectedRiskClass {
            func score(_ level: MockTrader.RiskLevel) -> RiskClass {
                switch level {
                case .low: return .riskClass2
                case .medium: return .riskClass4
                case .high: return .riskClass6
                }
            }
            filtered = filtered.filter { score($0.riskLevel) == rc }
        }
        if let spec = selectedSpecialization {
            filtered = filtered.filter { $0.specialization == spec }
        }
        switch selectedSortOption {
        case .name:
            filtered = filtered.sorted { $0.name < $1.name }
        case .performance:
            filtered = filtered.sorted { $0.performance > $1.performance }
        case .riskClass:
            func riskScore(_ level: MockTrader.RiskLevel) -> Int { level == .low ? 1 : (level == .medium ? 2 : 3) }
            filtered = filtered.sorted { riskScore($0.riskLevel) < riskScore($1.riskLevel) }
        case .experience:
            filtered = filtered.sorted { $0.experienceYears > $1.experienceYears }
        case .totalInvestors:
            filtered = filtered.sorted { $0.totalTrades > $1.totalTrades }
        case .minimumInvestment:
            break
        }
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
        func score(_ level: MockTrader.RiskLevel) -> RiskClass {
            switch level {
            case .low: return .riskClass2
            case .medium: return .riskClass4
            case .high: return .riskClass6
            }
        }
        return allTraders.filter { score($0.riskLevel) == riskClass }
    }

    func getTradersBySpecialization(_ specialization: String) -> [MockTrader] {
        return allTraders.filter { $0.specialization == specialization }
    }

    func getTopPerformers(limit: Int) -> [MockTrader] {
        return allTraders.sorted { $0.performance > $1.performance }.prefix(limit).map { $0 }
    }
}
