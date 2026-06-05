import Combine
@testable import FIN1
import Foundation

// MARK: - Mock Trader Data Service
final class MockTraderDataService: TraderDataServiceProtocol, @unchecked Sendable {
    @Published var traders: [InvestorTrader] = []
    @Published var filteredTraders: [InvestorTrader] = []
    @Published var searchText: String = ""
    @Published var selectedRiskClass: RiskClass?
    @Published var selectedSpecialization: String?
    @Published var selectedSortOption: TraderSortOption = .name
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    var dashboardTraders: [InvestorTrader] {
        self.allTraders.filter(\.isFromMockCatalog)
    }

    private var allTraders: [InvestorTrader] = []

    func refreshTraderCatalog() async {}
    func refreshParseUserIds() async {}

    // MARK: - Trader Data Management
    func loadTraderData() {
        self.isLoading = true
        let mocks: [MockTrader] = mockTraders.isEmpty ? Self.fallbackMocks : mockTraders
        self.allTraders = mocks.map { InvestorTrader(mock: $0, isFromMockCatalog: true) }
        self.traders = self.allTraders
        self.isLoading = false
        self.performSearch()
    }

    func refreshTraderData() {
        self.loadTraderData()
    }

    func addTrader(_ trader: InvestorTrader) {
        if !self.allTraders.contains(where: { $0.id == trader.id }) {
            self.allTraders.append(trader)
            self.traders = self.allTraders
            self.performSearch()
        }
    }

    func updateTrader(_ trader: InvestorTrader) {
        if let idx = allTraders.firstIndex(where: { $0.id == trader.id }) {
            self.allTraders[idx] = trader
            self.traders = self.allTraders
            self.performSearch()
        }
    }

    func removeTrader(_ trader: InvestorTrader) {
        self.allTraders.removeAll { $0.id == trader.id }
        self.traders = self.allTraders
        self.performSearch()
    }

    // MARK: - Search and Filtering
    func performSearch() {
        var filtered = self.allTraders
        if !self.searchText.isEmpty {
            filtered = filtered.filter { trader in
                trader.name.localizedCaseInsensitiveContains(self.searchText) ||
                    trader.specialization.localizedCaseInsensitiveContains(self.searchText) ||
                    trader.username.localizedCaseInsensitiveContains(self.searchText)
            }
        }
        if let riskClass = selectedRiskClass {
            func score(_ level: TraderRiskLevel) -> RiskClass {
                switch level {
                case .low: return .riskClass2
                case .medium: return .riskClass4
                case .high: return .riskClass6
                }
            }
            filtered = filtered.filter { score($0.riskLevel) == riskClass }
        }
        if let spec = selectedSpecialization {
            filtered = filtered.filter { $0.specialization == spec }
        }
        switch self.selectedSortOption {
        case .name:
            filtered = filtered.sorted { $0.name < $1.name }
        case .performance:
            filtered = filtered.sorted { $0.performance > $1.performance }
        case .riskClass:
            func riskScore(_ level: TraderRiskLevel) -> Int { level == .low ? 1 : (level == .medium ? 2 : 3) }
            filtered = filtered.sorted { riskScore($0.riskLevel) < riskScore($1.riskLevel) }
        case .experience:
            filtered = filtered.sorted { $0.experienceYears > $1.experienceYears }
        case .totalInvestors:
            filtered = filtered.sorted { $0.totalTrades > $1.totalTrades }
        case .minimumInvestment:
            break
        }
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
        self.allTraders.first {
            $0.catalogId == id || $0.parseUserId == id || $0.backendTraderId == id
        }
    }

    func getTradersByRiskClass(_ riskClass: RiskClass) -> [InvestorTrader] {
        func score(_ level: TraderRiskLevel) -> RiskClass {
            switch level {
            case .low: return .riskClass2
            case .medium: return .riskClass4
            case .high: return .riskClass6
            }
        }
        return self.allTraders.filter { score($0.riskLevel) == riskClass }
    }

    func getTradersBySpecialization(_ specialization: String) -> [InvestorTrader] {
        self.allTraders.filter { $0.specialization == specialization }
    }

    func getTopPerformers(limit: Int) -> [InvestorTrader] {
        self.allTraders.sorted { $0.performance > $1.performance }.prefix(limit).map { $0 }
    }

    private static let fallbackMocks: [MockTrader] = [
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
            totalReturn: 15_000.0,
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
            totalReturn: 5_000.0,
            riskLevel: .low,
            recentTrades: [],
            lastNTrades: 10,
            successfulTradesInLastN: 6,
            averageReturnLastNTrades: 2.8,
            consecutiveWinningTrades: 2,
            maxDrawdown: 8.0,
            sharpeRatio: 1.2
        ),
    ]
}
