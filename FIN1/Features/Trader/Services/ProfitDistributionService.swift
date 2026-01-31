import Foundation

// MARK: - Profit Distribution Service Implementation
/// Handles profit distribution for completed trades
/// Calculates commission using centralized services (single source of truth)
/// and distributes net profit to investments
final class ProfitDistributionService: ProfitDistributionServiceProtocol {

    // MARK: - Dependencies
    private let commissionCalculationService: any CommissionCalculationServiceProtocol
    private let investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)?
    private let commissionAccumulationService: (any CommissionAccumulationServiceProtocol)?
    private let poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?
    private let traderCashBalanceService: (any TraderCashBalanceServiceProtocol)?
    private let investmentService: (any InvestmentServiceProtocol)?
    private let userService: any UserServiceProtocol
    private let traderDataService: (any TraderDataServiceProtocol)?
    private let configurationService: (any ConfigurationServiceProtocol)?

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
        configurationService: (any ConfigurationServiceProtocol)? = nil
    ) {
        self.commissionCalculationService = commissionCalculationService
        self.investorGrossProfitService = investorGrossProfitService
        self.commissionAccumulationService = commissionAccumulationService
        self.poolTradeParticipationService = poolTradeParticipationService
        self.traderCashBalanceService = traderCashBalanceService
        self.investmentService = investmentService
        self.userService = userService
        self.traderDataService = traderDataService
        self.configurationService = configurationService
    }

    // MARK: - Profit Distribution

    func distributeProfit(for trade: Trade, order: Order) async -> Double {
        guard let poolTradeParticipationService = poolTradeParticipationService,
              let investmentService = investmentService else {
            print("⚠️ ProfitDistributionService: Required services are nil - profit distribution skipped")
            return 0.0
        }

        // Calculate gross trade profit
        let grossProfit = trade.calculatedProfit ?? trade.currentPnL ?? 0.0

        guard grossProfit > 0 else {
            print("ℹ️ ProfitDistributionService: Trade profit is \(grossProfit) (<= 0), skipping commission and distribution")
            return 0.0
        }

        print("💰 ProfitDistributionService: Processing profit distribution for trade \(trade.id)")
        print("   📊 Gross Profit: €\(String(format: "%.2f", grossProfit))")

        // Check if there are investors participating in this trade
        let participations = poolTradeParticipationService.getParticipations(forTradeId: trade.id)

        // Commission is only calculated when there are investors participating
        // Commission is a fee that investors pay to the trader, so no investors = no commission
        var totalCommission: Double = 0.0
        var totalInvestorGrossProfit: Double = 0.0
        let netProfit: Double

        if !participations.isEmpty {
            let commissionRate = configurationService?.effectiveCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate

            // Group participations by investment
            let participationsByInvestment = Dictionary(grouping: participations) { $0.investmentId }
            let allInvestments = investmentService.investments

            print("   👥 Number of Participations: \(participations.count)")
            print("   📊 Commission Rate: \(String(format: "%.0f", commissionRate * 100))%")

            // Calculate commission using centralized services (single source of truth)
            // This ensures consistency with Credit Note and Account Statement
            for (investmentId, _) in participationsByInvestment {
                guard allInvestments.first(where: { $0.id == investmentId }) != nil else {
                    continue
                }

                // Use centralized InvestorGrossProfitService for authoritative gross profit
                if let investorGrossProfitService = investorGrossProfitService {
                    do {
                        let investorGrossProfit = try await investorGrossProfitService.getGrossProfit(
                            for: investmentId,
                            tradeId: trade.id
                        )
                        let investorCommission = try await commissionCalculationService.calculateCommissionForInvestor(
                            investmentId: investmentId,
                            tradeId: trade.id,
                            commissionRate: commissionRate
                        )
                        totalInvestorGrossProfit += investorGrossProfit
                        totalCommission += investorCommission
                    } catch {
                        print("⚠️ ProfitDistributionService: Error calculating commission for investment \(investmentId): \(error)")
                    }
                }
            }

            // Net profit for distribution: full gross profit minus total commission
            netProfit = grossProfit - totalCommission

            print("   💵 Total Investor Gross Profit: €\(String(format: "%.2f", totalInvestorGrossProfit))")
            print("   💰 Total Commission (centralized): €\(String(format: "%.2f", totalCommission))")
        } else {
            // No investors = no commission (trader keeps full profit)
            totalCommission = 0.0
            netProfit = grossProfit
            print("   ℹ️ No investors participating - no commission calculated")
        }

        // Accumulate commissions for investors (only if commission > 0 and investors exist)
        if totalCommission > 0 && !participations.isEmpty {
            await accumulateCommissionsForInvestors(
                trade: trade,
                totalCommission: totalCommission,
                grossProfit: grossProfit
            )
        }

        // Distribute net profit (after commission) to participating pots
        let distributedProfit = await poolTradeParticipationService.distributeTradeProfit(
            tradeId: trade.id,
            totalProfit: netProfit
        )

        print("✅ ProfitDistributionService: Distributed €\(String(format: "%.2f", distributedProfit)) net profit to pots")
        print("   💰 Commission accumulated: €\(String(format: "%.2f", totalCommission))")
        print("   💵 Net profit distributed: €\(String(format: "%.2f", netProfit))")

        // Update investment values with accumulated profits
        await investmentService.updateInvestmentProfitsFromTrades()

        return distributedProfit
    }

    // MARK: - Private Helpers

    /// Accumulates commissions for investors using centralized calculation services
    /// Ensures consistency with Credit Note and Account Statement values
    private func accumulateCommissionsForInvestors(
        trade: Trade,
        totalCommission: Double,
        grossProfit: Double
    ) async {
        guard let commissionAccumulationService = commissionAccumulationService,
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
        let traderId = findTraderIdForMatching() ?? trade.traderId

        // Group participations by investment to get unique investors
        let participationsByInvestment = Dictionary(grouping: participations) { $0.investmentId }

        // Get all investments to find investor IDs
        let allInvestments = investmentService.investments

        let commissionRate = configurationService?.effectiveCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate

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
                    investorCommissionShare = try await commissionCalculationService.calculateCommissionForInvestor(
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
            await commissionAccumulationService.recordCommission(
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

        print("✅ ProfitDistributionService: Accumulated total commission of €\(String(format: "%.2f", totalCommission)) for trade #\(trade.tradeNumber)")
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
