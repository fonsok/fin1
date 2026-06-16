import Foundation
import SwiftUI

// MARK: - Commission Breakdown Item Model

struct CommissionBreakdownItem: Identifiable {
    let id: String
    let investorName: String
    let grossProfit: Double
    let commission: Double
}

// MARK: - Commission Breakdown ViewModel

/// ViewModel for commission breakdown calculations
/// Extracts service logic from the View layer per MVVM principles
@MainActor
final class CommissionBreakdownViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var breakdownItems: [CommissionBreakdownItem] = []
    @Published private(set) var totalCommission: Double = 0.0
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Dependencies

    private let tradeId: String
    private let poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol
    private let investmentService: any InvestmentServiceProtocol
    private let userService: any UserServiceProtocol
    private let investorGrossProfitService: any InvestorGrossProfitServiceProtocol
    private let commissionCalculationService: any CommissionCalculationServiceProtocol
    private let settlementAPIService: (any SettlementAPIServiceProtocol)?

    // MARK: - Computed Properties

    var commissionRate: Double {
        self.configurationService.effectiveCommissionRate
    }

    var formattedCommissionRate: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 3
        formatter.decimalSeparator = ","
        return formatter.string(from: NSNumber(value: self.commissionRate))
            ?? String(format: "%.1f", self.commissionRate).replacingOccurrences(of: ".", with: ",")
    }

    private var monetaryServerOnly: Bool {
        self.configurationService.investorStatementServerOnly
    }

    // MARK: - Initialization

    init(
        tradeId: String,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        userService: any UserServiceProtocol,
        investorGrossProfitService: any InvestorGrossProfitServiceProtocol,
        commissionCalculationService: any CommissionCalculationServiceProtocol,
        settlementAPIService: (any SettlementAPIServiceProtocol)?
    ) {
        self.tradeId = tradeId
        self.poolTradeParticipationService = poolTradeParticipationService
        self.configurationService = configurationService
        self.investmentService = investmentService
        self.userService = userService
        self.investorGrossProfitService = investorGrossProfitService
        self.commissionCalculationService = commissionCalculationService
        self.settlementAPIService = settlementAPIService
    }

    /// Convenience initializer using AppServices
    convenience init(tradeId: String, services: AppServices) {
        self.init(
            tradeId: tradeId,
            poolTradeParticipationService: services.poolTradeParticipationService,
            configurationService: services.configurationService,
            investmentService: services.investmentService,
            userService: services.userService,
            investorGrossProfitService: services.investorGrossProfitService,
            commissionCalculationService: services.commissionCalculationService,
            settlementAPIService: services.settlementAPIService
        )
    }

    // MARK: - Public Methods

    func loadBreakdown() async {
        self.isLoading = true
        self.errorMessage = nil
        self.showError = false

        if let user = self.userService.currentUser, user.role == .trader {
            await self.investmentService.fetchFromBackendForTrader(user: user)
        }

        let investments = self.investmentsForNameLookup()
        let participations = self.poolTradeParticipationService.getParticipations(forTradeId: self.tradeId)

        if participations.isEmpty {
            await self.loadSettlementAggregateBreakdown(investments: investments)
            self.isLoading = false
            return
        }

        let investmentIds = Array(Set(participations.map(\.investmentId)))

        if let api = settlementAPIService,
           let serverLines = await TradeInvestorCommissionBreakdownLoader.load(
               tradeId: tradeId,
               investmentIds: investmentIds,
               investments: investments,
               settlementAPIService: api
           ) {
            self.apply(lines: serverLines)
            self.isLoading = false
            return
        }

        if self.monetaryServerOnly {
            self.breakdownItems = []
            self.totalCommission = 0
            self.errorMessage = "Provisionen konnten nicht aus Server-Belegen geladen werden."
            self.showError = true
            self.isLoading = false
            return
        }

        let localLines = await TradeInvestorCommissionBreakdownLoader.loadLocalEstimate(
            tradeId: self.tradeId,
            investmentIds: investmentIds,
            investments: investments,
            investorGrossProfitService: self.investorGrossProfitService,
            commissionCalculationService: self.commissionCalculationService,
            commissionRate: self.commissionRate
        )
        self.apply(lines: localLines)
        self.isLoading = false
    }

    private func investmentsForNameLookup() -> [Investment] {
        guard let user = self.userService.currentUser else {
            return self.investmentService.investments
        }
        let forTrader = self.investmentService.getInvestments(forTrader: user.id)
        if forTrader.isEmpty {
            return self.investmentService.investments
        }
        var byId: [String: Investment] = [:]
        for investment in self.investmentService.investments {
            byId[investment.id] = investment
        }
        for investment in forTrader {
            byId[investment.id] = investment
        }
        return Array(byId.values)
    }

    private func apply(lines: [TradeInvestorCommissionLine]) {
        self.breakdownItems = lines.map {
            CommissionBreakdownItem(
                id: $0.investmentId,
                investorName: $0.investorName,
                grossProfit: $0.grossProfit,
                commission: $0.commission
            )
        }
        self.totalCommission = lines.reduce(0) { $0 + $1.commission }
    }

    /// Aggregate breakdown when no local participations (settlement commissions only).
    private func loadSettlementAggregateBreakdown(investments: [Investment]) async {
        guard let settlementAPIService else {
            self.breakdownItems = []
            self.totalCommission = 0
            return
        }

        guard let resolved = await TradeCommissionSettlementBreakdownResolver.resolve(
            tradeId: tradeId,
            creditNoteDocumentId: nil,
            investments: investments,
            settlementAPIService: settlementAPIService
        ) else {
            self.breakdownItems = []
            self.totalCommission = 0
            self.errorMessage = "Investor-Aufschlüsselung konnte nicht geladen werden."
            self.showError = true
            return
        }

        self.apply(lines: resolved.lines)
    }
}
