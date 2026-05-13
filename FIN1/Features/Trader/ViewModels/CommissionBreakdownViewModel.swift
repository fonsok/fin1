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

    // MARK: - Initialization

    init(
        tradeId: String,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        investorGrossProfitService: any InvestorGrossProfitServiceProtocol,
        commissionCalculationService: any CommissionCalculationServiceProtocol,
        settlementAPIService: (any SettlementAPIServiceProtocol)?
    ) {
        self.tradeId = tradeId
        self.poolTradeParticipationService = poolTradeParticipationService
        self.configurationService = configurationService
        self.investmentService = investmentService
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
            investorGrossProfitService: services.investorGrossProfitService,
            commissionCalculationService: services.commissionCalculationService,
            settlementAPIService: services.settlementAPIService
        )
    }

    // MARK: - Public Methods

    func loadBreakdown() async {
        self.isLoading = true

        // Get participations for this trade
        let participations = self.poolTradeParticipationService.getParticipations(forTradeId: self.tradeId)

        guard !participations.isEmpty else {
            await self.loadBackendFallbackBreakdown()
            self.isLoading = false
            return
        }

        // Get all investments to map investmentId to investorId
        let allInvestments = self.investmentService.investments

        // Group participations by investment to get unique investors
        let participationsByInvestment = Dictionary(grouping: participations) { $0.investmentId }

        var items: [CommissionBreakdownItem] = []
        var total: Double = 0.0

        // Use centralized services to get gross profit and calculate commission
        // This ensures consistency with Collection Bill calculations
        for (investmentId, _) in participationsByInvestment {
            guard let investment = allInvestments.first(where: { $0.id == investmentId }) else {
                continue
            }

            do {
                // Use centralized InvestorGrossProfitService to get gross profit
                let investorGrossProfit = try await investorGrossProfitService.getGrossProfit(
                    for: investmentId,
                    tradeId: self.tradeId
                )

                // Use centralized CommissionCalculationService to calculate commission
                let investorCommission = try await commissionCalculationService.calculateCommissionForInvestor(
                    investmentId: investmentId,
                    tradeId: self.tradeId,
                    commissionRate: self.commissionRate
                )

                // Use investor username from investment (set during investment creation)
                let investorName = investment.investorName

                items.append(CommissionBreakdownItem(
                    id: investmentId,
                    investorName: investorName,
                    grossProfit: investorGrossProfit,
                    commission: investorCommission
                ))

                total += investorCommission
            } catch {
                let appError = error.toAppError()
                let errorMsg = "Fehler bei der Berechnung für Investor \(investment.investorId.prefix(8)): \(appError.errorDescription ?? "An error occurred")"
                print("⚠️ CommissionBreakdownViewModel: \(errorMsg)")
                self.errorMessage = errorMsg
                self.showError = true
                // Continue with other investors even if one fails
                continue
            }
        }

        self.breakdownItems = items
        self.totalCommission = total
        self.isLoading = false
    }

    private func loadBackendFallbackBreakdown() async {
        guard let settlementAPIService else {
            self.breakdownItems = []
            self.totalCommission = 0
            return
        }

        do {
            let settlement = try await settlementAPIService.fetchTradeSettlement(tradeId: self.tradeId)
            let grouped = Dictionary(grouping: settlement.commissions) { $0.investmentId ?? $0.objectId }
            let allInvestments = self.investmentService.investments
            var items: [CommissionBreakdownItem] = []
            var total: Double = 0

            for (key, rows) in grouped {
                let commission = rows.compactMap { $0.commissionAmount }.reduce(0, +)
                guard commission > 0 else { continue }
                let grossProfit = self.commissionRate > 0 ? (commission / self.commissionRate) : 0
                let knownInvestment = allInvestments.first(where: { $0.id == key })
                let investorName = knownInvestment?.investorName
                    ?? self.displayNameFromInvestorId(rows.first?.investorId)
                    ?? "Investor"

                items.append(CommissionBreakdownItem(
                    id: key,
                    investorName: investorName,
                    grossProfit: grossProfit,
                    commission: commission
                ))
                total += commission
            }

            self.breakdownItems = items.sorted { $0.investorName < $1.investorName }
            self.totalCommission = total
        } catch {
            self.breakdownItems = []
            self.totalCommission = 0
            self.errorMessage = "Investor-Aufschlüsselung konnte nicht geladen werden."
            self.showError = true
        }
    }

    private func displayNameFromInvestorId(_ investorId: String?) -> String? {
        guard let investorId, investorId.hasPrefix("user:") else { return nil }
        let raw = String(investorId.dropFirst("user:".count))
        let base = raw.split(separator: "@").first.map(String.init) ?? raw
        return base.replacingOccurrences(of: ".", with: " ")
    }
}





