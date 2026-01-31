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

    // MARK: - Computed Properties

    var commissionRate: Double {
        configurationService.traderCommissionRate
    }

    var formattedCommissionRate: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 3
        formatter.decimalSeparator = ","
        return formatter.string(from: NSNumber(value: commissionRate))
            ?? String(format: "%.1f", commissionRate).replacingOccurrences(of: ".", with: ",")
    }

    // MARK: - Initialization

    init(
        tradeId: String,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        investorGrossProfitService: any InvestorGrossProfitServiceProtocol,
        commissionCalculationService: any CommissionCalculationServiceProtocol
    ) {
        self.tradeId = tradeId
        self.poolTradeParticipationService = poolTradeParticipationService
        self.configurationService = configurationService
        self.investmentService = investmentService
        self.investorGrossProfitService = investorGrossProfitService
        self.commissionCalculationService = commissionCalculationService
    }

    /// Convenience initializer using AppServices
    convenience init(tradeId: String, services: AppServices) {
        self.init(
            tradeId: tradeId,
            poolTradeParticipationService: services.poolTradeParticipationService,
            configurationService: services.configurationService,
            investmentService: services.investmentService,
            investorGrossProfitService: services.investorGrossProfitService,
            commissionCalculationService: services.commissionCalculationService
        )
    }

    // MARK: - Public Methods

    func loadBreakdown() async {
        isLoading = true

        // Get participations for this trade
        let participations = poolTradeParticipationService.getParticipations(forTradeId: tradeId)

        guard !participations.isEmpty else {
            breakdownItems = []
            isLoading = false
            return
        }

        // Get all investments to map investmentId to investorId
        let allInvestments = investmentService.investments

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
                    tradeId: tradeId
                )

                // Use centralized CommissionCalculationService to calculate commission
                let investorCommission = try await commissionCalculationService.calculateCommissionForInvestor(
                    investmentId: investmentId,
                    tradeId: tradeId,
                    commissionRate: commissionRate
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
                errorMessage = errorMsg
                showError = true
                // Continue with other investors even if one fails
                continue
            }
        }

        breakdownItems = items
        totalCommission = total
        isLoading = false
    }
}





