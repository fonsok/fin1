import Foundation

// MARK: - Profit Distribution Service Implementation
/// Handles profit distribution for completed trades
/// Calculates commission using centralized services (single source of truth)
/// and distributes net profit to investments
final class ProfitDistributionService: ProfitDistributionServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies
    private let commissionCalculationService: any CommissionCalculationServiceProtocol
    private let investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)?
    private let commissionAccumulationBridge: UncheckedCommissionAccumulationBridge?
    private let poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?
    nonisolated(unsafe) private let traderCashBalanceService: (any TraderCashBalanceServiceProtocol)?
    private let investmentService: (any InvestmentServiceProtocol)?
    private let userService: any UserServiceProtocol
    private let traderDataService: (any TraderDataServiceProtocol)?
    private let configurationService: any ConfigurationServiceProtocol
    private let settlementAPIService: (any SettlementAPIServiceProtocol)?

    // MARK: - Initialization
    init(
        commissionCalculationService: any CommissionCalculationServiceProtocol,
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)? = nil,
        commissionAccumulationService: (any CommissionAccumulationServiceProtocol)? = nil,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
        traderCashBalanceService: (any TraderCashBalanceServiceProtocol)? = nil,
        investmentService: (any InvestmentServiceProtocol)? = nil,
        userService: any UserServiceProtocol,
        traderDataService: (any TraderDataServiceProtocol)? = nil,
        configurationService: any ConfigurationServiceProtocol,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) {
        self.commissionCalculationService = commissionCalculationService
        self.investorGrossProfitService = investorGrossProfitService
        self.commissionAccumulationBridge = commissionAccumulationService.map { UncheckedCommissionAccumulationBridge($0) }
        self.poolTradeParticipationService = poolTradeParticipationService
        self.traderCashBalanceService = traderCashBalanceService
        self.investmentService = investmentService
        self.userService = userService
        self.traderDataService = traderDataService
        self.configurationService = configurationService
        self.settlementAPIService = settlementAPIService
    }

    // MARK: - Profit Distribution

    func distributeProfit(for trade: Trade, order: Order) async -> Double {
        guard let poolTradeParticipationService = poolTradeParticipationService,
              let investmentService = investmentService else {
            print("⚠️ ProfitDistributionService: Required services are nil - profit distribution skipped")
            return 0.0
        }

        let grossProfit = trade.calculatedProfit ?? trade.currentPnL ?? 0.0
        guard grossProfit > 0 else {
            print("ℹ️ ProfitDistributionService: Trade profit is \(grossProfit) (<= 0), skipping")
            return 0.0
        }

        print("💰 ProfitDistributionService: Processing trade \(trade.id), grossProfit=€\(String(format: "%.2f", grossProfit))")

        // --- Phase 3: Backend is authoritative ---
        // If backend has settled this trade, read its values instead of recalculating locally.
        if let settlementService = settlementAPIService {
            if let summary = try? await settlementService.fetchTradeSettlement(tradeId: trade.id),
               summary.isSettledByBackend {
                print("✅ ProfitDistributionService: Trade \(trade.id) settled by backend — reading authoritative values")
                let backendCommission = summary.totalFees
                let backendNetProfit = summary.netProfit

                // Local UI bookkeeping: credit commission to trader cash balance for display
                if backendCommission > 0, let traderCashBalanceService {
                    await traderCashBalanceService.processCommissionPayment(
                        traderId: trade.traderId,
                        commissionAmount: backendCommission,
                        tradeId: trade.id
                    )
                }

                // Distribute net profit to participating pools (local state for UI)
                let distributed = await poolTradeParticipationService.distributeTradeProfit(
                    tradeId: trade.id,
                    totalProfit: backendNetProfit
                )

                await investmentService.updateInvestmentProfitsFromTrades()

                print("✅ ProfitDistributionService: Backend-authoritative distribution complete")
                print("   💰 Commission (backend): €\(String(format: "%.2f", backendCommission))")
                print("   💵 Net profit distributed: €\(String(format: "%.2f", backendNetProfit))")
                return distributed
            }
        }

        print("⚠️ ProfitDistributionService: Backend settlement not available — skipping distribution")
        return 0.0
    }

    private func findTraderIdForMatching() -> String? {
        TraderMatchingHelper.findTraderIdForMatching(
            currentUser: self.userService.currentUser,
            traderDataService: self.traderDataService
        )
    }
}

// MARK: - Commission accumulation bridge (Swift 6)
/// `CommissionAccumulationServiceProtocol` is `@MainActor`; this service is `@unchecked Sendable` for coordinator wiring.
private final class UncheckedCommissionAccumulationBridge: @unchecked Sendable {
    private let service: any CommissionAccumulationServiceProtocol

    init(_ service: any CommissionAccumulationServiceProtocol) {
        self.service = service
    }

    func recordCommission(
        investorId: String,
        traderId: String,
        tradeId: String,
        tradeNumber: Int,
        commissionAmount: Double,
        grossProfit: Double
    ) async {
        await self.service.recordCommission(
            investorId: investorId,
            traderId: traderId,
            tradeId: tradeId,
            tradeNumber: tradeNumber,
            commissionAmount: commissionAmount,
            grossProfit: grossProfit
        )
    }
}
