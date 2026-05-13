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

        // --- Fallback: local calculation (backend unreachable or not yet settled) ---
        print("ℹ️ ProfitDistributionService: Backend settlement not available — using local calculation")
        return await self.distributeLocalFallback(trade: trade, grossProfit: grossProfit)
    }

    /// Local fallback: calculates commission and distributes profit entirely on-device.
    /// Labelled as estimation path — backend is the source of truth.
    private func distributeLocalFallback(trade: Trade, grossProfit: Double) async -> Double {
        guard let poolTradeParticipationService = poolTradeParticipationService,
              let investmentService = investmentService else { return 0.0 }

        let participations = poolTradeParticipationService.getParticipations(forTradeId: trade.id)

        var totalCommission: Double = 0.0
        let netProfit: Double

        if !participations.isEmpty {
            let commissionRate = self.configurationService.effectiveCommissionRate
            let participationsByInvestment = Dictionary(grouping: participations) { $0.investmentId }
            let allInvestments = investmentService.investments

            for (investmentId, _) in participationsByInvestment {
                guard allInvestments.first(where: { $0.id == investmentId }) != nil else { continue }

                if let investorGrossProfitService {
                    do {
                        let investorGrossProfit = try await investorGrossProfitService.getGrossProfit(
                            for: investmentId, tradeId: trade.id
                        )
                        let investorCommission = try await commissionCalculationService.calculateCommissionForInvestor(
                            investmentId: investmentId, tradeId: trade.id, commissionRate: commissionRate
                        )
                        totalCommission += investorCommission
                        _ = investorGrossProfit
                    } catch {
                        print("⚠️ ProfitDistributionService [local fallback]: Error for investment \(investmentId): \(error)")
                    }
                }
            }
            netProfit = grossProfit - totalCommission
        } else {
            netProfit = grossProfit
        }

        if totalCommission > 0 && !participations.isEmpty {
            await self.accumulateCommissionsForInvestors(trade: trade, totalCommission: totalCommission, grossProfit: grossProfit)
            if let traderCashBalanceService {
                await traderCashBalanceService.processCommissionPayment(
                    traderId: trade.traderId, commissionAmount: totalCommission, tradeId: trade.id
                )
            }
        }

        let distributed = await poolTradeParticipationService.distributeTradeProfit(
            tradeId: trade.id, totalProfit: netProfit
        )
        await investmentService.updateInvestmentProfitsFromTrades()
        return distributed
    }

    // MARK: - Private Helpers

    /// Accumulates commissions for investors using centralized calculation services
    /// Ensures consistency with Credit Note and Account Statement values
    private func accumulateCommissionsForInvestors(
        trade: Trade,
        totalCommission: Double,
        grossProfit: Double
    ) async {
        guard let commissionAccumulationBridge = commissionAccumulationBridge,
              let poolTradeParticipationService = poolTradeParticipationService,
              let investmentService = investmentService else {
            print("⚠️ ProfitDistributionService: Required services are nil - commission not accumulated!")
            return
        }

        // Get all participations for this trade
        let participations = poolTradeParticipationService.getParticipations(forTradeId: trade.id)

        guard !participations.isEmpty else {
            print("ℹ️ ProfitDistributionService: No participations found for trade \(trade.id) - no commission to accumulate")
            return
        }

        // Get trader ID
        let traderId = self.findTraderIdForMatching() ?? trade.traderId

        // Group participations by investment to get unique investors
        let participationsByInvestment = Dictionary(grouping: participations) { $0.investmentId }

        // Get all investments to find investor IDs
        let allInvestments = investmentService.investments

        let commissionRate = self.configurationService.effectiveCommissionRate

        // Accumulate commission for each investor using centralized services
        for (investmentId, _) in participationsByInvestment {
            guard let investment = allInvestments.first(where: { $0.id == investmentId }) else {
                print("⚠️ ProfitDistributionService: Investment \(investmentId) not found - skipping commission accumulation")
                continue
            }

            // Use centralized services for authoritative values (single source of truth)
            var investorGrossProfitShare: Double = 0.0
            var investorCommissionShare: Double = 0.0

            if let investorGrossProfitService = investorGrossProfitService {
                do {
                    investorGrossProfitShare = try await investorGrossProfitService.getGrossProfit(
                        for: investmentId,
                        tradeId: trade.id
                    )
                    investorCommissionShare = try await self.commissionCalculationService.calculateCommissionForInvestor(
                        investmentId: investmentId,
                        tradeId: trade.id,
                        commissionRate: commissionRate
                    )
                } catch {
                    print("⚠️ ProfitDistributionService: Error calculating for investment \(investmentId): \(error)")
                    continue
                }
            } else {
                print("⚠️ ProfitDistributionService: InvestorGrossProfitService unavailable - skipping \(investmentId)")
                continue
            }

            // Record commission accumulation for this investor
            await commissionAccumulationBridge.recordCommission(
                investorId: investment.investorId,
                traderId: traderId,
                tradeId: trade.id,
                tradeNumber: trade.tradeNumber,
                commissionAmount: investorCommissionShare,
                grossProfit: investorGrossProfitShare
            )

            print("💰 ProfitDistributionService: Accumulated commission for investor \(investment.investorId)")
            print("   📊 Investment ID: \(investmentId)")
            print("   💵 Gross Profit (centralized): €\(String(format: "%.2f", investorGrossProfitShare))")
            print("   💰 Commission (centralized): €\(String(format: "%.2f", investorCommissionShare))")
        }

        print(
            "✅ ProfitDistributionService: Accumulated total commission of €\(String(format: "%.2f", totalCommission)) for trade #\(trade.tradeNumber)"
        )
    }

    /// Finds the trader ID to use for investment matching
    /// First tries to find MockTrader by username from user's email, then falls back to user ID
    private func findTraderIdForMatching() -> String? {
        guard let currentUser = userService.currentUser else {
            print("   ⚠️ No current user - cannot find trader ID")
            return nil
        }

        // Extract username from email (e.g., "trader1@test.com" -> "trader1")
        let username = currentUser.email.components(separatedBy: "@").first ?? ""
        print("   🔍 Extracted username from email '\(currentUser.email)': '\(username)'")

        // Try to find MockTrader by username
        if let traderDataService = traderDataService {
            // 1) Exact username match
            if let mockTrader = traderDataService.traders.first(where: { $0.username == username }) {
                let traderId = mockTrader.id.uuidString
                print("   ✅ Found MockTrader by username '\(username)': ID='\(traderId)'")
                return traderId
            }
            // 2) Try display name match (FirstName LastName) against MockTrader.name
            let displayName = "\(currentUser.firstName) \(currentUser.lastName)".trimmingCharacters(in: .whitespaces)
            if let byName = traderDataService.traders.first(where: { $0.name.caseInsensitiveCompare(displayName) == .orderedSame }) {
                let traderId = byName.id.uuidString
                print("   ✅ Found MockTrader by display name '\(displayName)': ID='\(traderId)'")
                return traderId
            }
            // 3) Fuzzy contains on name as last resort
            if let fuzzy = traderDataService.traders.first(where: { $0.name.localizedCaseInsensitiveContains(username) }) {
                let traderId = fuzzy.id.uuidString
                print("   ✅ Found MockTrader by fuzzy name contains '\(username)': ID='\(traderId)'")
                return traderId
            }
            print("   ⚠️ No MockTrader found for username/name '\(username)'/'\(displayName)' in \(traderDataService.traders.count) traders")
            print("   📋 Available trader usernames: \(traderDataService.traders.map { $0.username })")
        } else {
            print("   ⚠️ traderDataService is nil - cannot lookup by username")
        }

        // Fallback to user ID
        let userId = currentUser.id
        print("   🔄 Falling back to user ID: '\(userId)'")
        return userId
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
