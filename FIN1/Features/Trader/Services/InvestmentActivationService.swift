import Foundation

// MARK: - Investment Activation Service Implementation
/// Handles investment activation when buy orders complete
/// Activates investments and records pool participations
final class InvestmentActivationService: InvestmentActivationServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies
    private let investmentService: (any InvestmentServiceProtocol)?
    private let poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?
    private let userService: any UserServiceProtocol
    private let traderDataService: (any TraderDataServiceProtocol)?

    // MARK: - Initialization
    init(
        investmentService: (any InvestmentServiceProtocol)? = nil,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
        userService: any UserServiceProtocol,
        traderDataService: (any TraderDataServiceProtocol)? = nil
    ) {
        self.investmentService = investmentService
        self.poolTradeParticipationService = poolTradeParticipationService
        self.userService = userService
        self.traderDataService = traderDataService
    }

    // MARK: - Investment Activation

    func activateInvestmentsForBuyOrder(order: Order, trade: Trade) async -> [String] {
        guard let investmentService = investmentService else {
            print("⚠️ InvestmentActivationService: investmentService is nil - investment activation skipped!")
            return []
        }

        // Find trader ID by matching username to MockTrader.
        // Keep order.traderId as fallback candidate because environments may use
        // mixed traderId formats (Parse userId / user:email / mock UUID / username).
        let matchedTraderId = TraderMatchingHelper.findTraderIdForMatching(
            currentUser: self.userService.currentUser,
            traderDataService: self.traderDataService
        )
        let traderId = matchedTraderId ?? order.traderId

        print("🔍 InvestmentActivationService.activateInvestmentsForBuyOrder:")
        print("   📋 Order traderId: '\(order.traderId)'")
        print("   👤 Current user: \(self.userService.currentUser?.email ?? "nil")")
        print("   🎯 Using traderId: '\(traderId)'")
        print("   📊 Total investments in service: \(investmentService.investments.count)")

        // Log all investments for debugging
        self.logInvestments(investmentService: investmentService, traderId: traderId)

        // Find eligible investments
        let eligibleInvestments = self.findEligibleInvestments(
            investmentService: investmentService,
            traderIdCandidates: self.buildTraderIdCandidates(primaryTraderId: traderId, orderTraderId: order.traderId)
        )

        guard !eligibleInvestments.isEmpty else {
            print("ℹ️ InvestmentActivationService: No eligible investments to activate for trader \(traderId)")
            return []
        }

        print("✅ InvestmentActivationService: Found \(eligibleInvestments.count) eligible investments for trader \(traderId)")

        // Select and activate investments (one per investor using round-robin)
        let activatedInvestments = await selectAndActivateInvestments(
            eligibleInvestments: eligibleInvestments,
            investmentService: investmentService,
            traderId: traderId
        )

        // Record pool participations
        if let poolTradeParticipationService = poolTradeParticipationService {
            await PoolParticipationRecorder.recordParticipations(
                activatedInvestments: activatedInvestments,
                order: order,
                trade: trade,
                poolTradeParticipationService: poolTradeParticipationService
            )
        }

        return activatedInvestments.map { $0.id }
    }

    // MARK: - Private Helpers

    private func logInvestments(investmentService: any InvestmentServiceProtocol, traderId: String) {
        guard !investmentService.investments.isEmpty else {
            print("   ⚠️ No investments found in service!")
            return
        }

        print("   📋 All investments in service:")
        for (index, inv) in investmentService.investments.enumerated() {
            print("      [\(index)] Investment ID: \(inv.id)")
            print("         Trader ID: '\(inv.traderId)'")
            print("         Trader Name: \(inv.traderName)")
            print("         Status: \(inv.status.rawValue)")
            print("         Pool Status: \(inv.reservationStatus.rawValue)")
            print("         Pool Number: \(inv.sequenceNumber ?? 0)")
            print("         Amount: €\(inv.amount)")
            print("         Match check: '\(inv.traderId)' == '\(traderId)' ? \(inv.traderId == traderId)")
        }
    }

    private func findEligibleInvestments(
        investmentService: any InvestmentServiceProtocol,
        traderIdCandidates: [String]
    ) -> [Investment] {
        let normalizedCandidates = Set(
            traderIdCandidates
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )

        // Filter for reserved investments matching this trader by any known id format.
        var eligibleInvestments = investmentService.investments.filter {
            normalizedCandidates.contains($0.traderId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) &&
                $0.status == .active &&
                $0.reservationStatus == .reserved
        }

        // Fallback: if none matched by traderId, try matching by trader display name
        if eligibleInvestments.isEmpty {
            let displayName = "\(userService.currentUser?.firstName ?? "") \(self.userService.currentUser?.lastName ?? "")".trimmingCharacters(
                in: .whitespaces
            )
            let alt = investmentService.investments.filter {
                $0.traderName.caseInsensitiveCompare(displayName) == .orderedSame &&
                    $0.status == .active &&
                    $0.reservationStatus == .reserved
            }
            if !alt.isEmpty {
                print("   🔄 Fallback match by name '\(displayName)': \(alt.count) eligible investments")
                eligibleInvestments = alt
            } else {
                print("   ℹ️ No eligible investments found by id or name for trader candidates \(traderIdCandidates)")
            }
        }

        return eligibleInvestments
    }

    private func buildTraderIdCandidates(primaryTraderId: String, orderTraderId: String) -> [String] {
        var candidates = [primaryTraderId, orderTraderId]

        if let email = userService.currentUser?.email.lowercased() {
            candidates.append(email)
            candidates.append("user:\(email)")
            if let username = email.components(separatedBy: "@").first, !username.isEmpty {
                candidates.append(username)
            }
        }

        let displayName = "\(userService.currentUser?.firstName ?? "") \(self.userService.currentUser?.lastName ?? "")"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !displayName.isEmpty {
            candidates.append(displayName)
        }

        // Preserve order but remove duplicates/empties.
        var seen = Set<String>()
        return candidates.filter {
            let key = $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if key.isEmpty || seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func selectAndActivateInvestments(
        eligibleInvestments: [Investment],
        investmentService: any InvestmentServiceProtocol,
        traderId: String
    ) async -> [Investment] {
        // Group investments by investor ID
        let investmentsByInvestor = Dictionary(grouping: eligibleInvestments) { $0.investorId }
        print("   📊 Unique investors: \(investmentsByInvestor.keys.count)")

        // Select ONE investment per investor using round-robin
        var selectedInvestments: [Investment] = []
        for (investorId, investorInvestments) in investmentsByInvestor {
            if let selectedInvestment = await investmentService.selectNextInvestmentForInvestor(investorId, traderId: traderId) {
                selectedInvestments.append(selectedInvestment)
                print(
                    "   👤 Investor \(investorId): Selected investment \(selectedInvestment.id) via round-robin (out of \(investorInvestments.count) eligible)"
                )
            } else {
                // Fallback: use oldest investment
                let sortedInvestments = investorInvestments.sorted(by: { $0.createdAt < $1.createdAt })
                if let fallbackInvestment = sortedInvestments.first {
                    selectedInvestments.append(fallbackInvestment)
                    print(
                        "   👤 Investor \(investorId): Selected investment \(fallbackInvestment.id) (fallback, out of \(investorInvestments.count) eligible)"
                    )
                }
            }
        }

        // Activate all selected investments
        var activatedInvestments: [Investment] = []
        for selectedInvestment in selectedInvestments {
            await investmentService.markNextInvestmentAsActive(for: selectedInvestment.id)

            if let refreshed = investmentService.investments.first(
                where: { $0.id == selectedInvestment.id && $0.reservationStatus == .active }
            ) {
                activatedInvestments.append(refreshed)
                print("✅ InvestmentActivationService: Activated investment \(refreshed.id) from investor \(refreshed.investorId)")
            }
        }

        return activatedInvestments
    }
}
