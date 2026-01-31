import Foundation

// MARK: - Buy Order Investment Data Provider Protocol

/// Protocol for providing investment data for buy orders
/// Extracts complex investment fetching and filtering logic from BuyOrderViewModel
protocol BuyOrderInvestmentDataProviderProtocol {
    /// Fetches reserved investments for the current trader using Round Robin selection
    /// - Parameters:
    ///   - traderId: The trader's ID
    ///   - currentUser: The current user
    /// - Returns: Array of investments, one per investor (Round Robin)
    func fetchReservedInvestments(
        traderId: String?,
        currentUser: User?
    ) -> [Investment]

    /// Finds the trader ID to use for investment matching
    /// - Parameter currentUser: The current user
    /// - Returns: Matched trader ID or nil
    func findTraderIdForMatching(currentUser: User?) -> String?
}

// MARK: - Implementation

/// Provides investment data for buy orders with Round Robin selection
/// Extracted from BuyOrderViewModel to reduce file size and improve testability
final class BuyOrderInvestmentDataProvider: BuyOrderInvestmentDataProviderProtocol {

    private let investmentService: any InvestmentServiceProtocol
    private let traderDataService: (any TraderDataServiceProtocol)?

    init(
        investmentService: any InvestmentServiceProtocol,
        traderDataService: (any TraderDataServiceProtocol)?
    ) {
        self.investmentService = investmentService
        self.traderDataService = traderDataService
    }

    func fetchReservedInvestments(
        traderId: String?,
        currentUser: User?
    ) -> [Investment] {
        print("🔍 BuyOrderInvestmentDataProvider: Fetching reserved investments")

        guard let currentUser = currentUser else {
            print("   ❌ No current user")
            return []
        }

        guard currentUser.role == .trader else {
            print("   ❌ User is not a trader")
            return []
        }

        // Use provided traderId or find one
        var effectiveTraderId = traderId ?? findTraderIdForMatching(currentUser: currentUser) ?? currentUser.id
        print("   📊 Using trader ID: \(effectiveTraderId)")

        // Get ALL investments for this trader
        var allTraderInvestments = investmentService.getInvestments(forTrader: effectiveTraderId)
        print("   📊 Total investments for trader: \(allTraderInvestments.count)")

        // FALLBACK: If no investments found and traderDataService is nil, try matching by name
        if allTraderInvestments.isEmpty && traderDataService == nil {
            allTraderInvestments = fallbackMatchByName(currentUser: currentUser, effectiveTraderId: &effectiveTraderId)
        }

        // Filter investments - match BuyOrderInvestmentCalculator logic
        let filteredInvestments = filterEligibleInvestments(allTraderInvestments)
        print("   📊 Filtered to \(filteredInvestments.count) eligible investments")

        // Apply Round Robin: Select ONE investment per investor
        let selectedInvestments = applyRoundRobinSelection(filteredInvestments)
        print("   ✅ Selected \(selectedInvestments.count) investments (Round Robin)")

        return selectedInvestments
    }

    func findTraderIdForMatching(currentUser: User?) -> String? {
        guard let currentUser = currentUser else {
            return nil
        }

        // Try to find MockTrader by username from user's email
        if let traderDataService = traderDataService {
            let email = currentUser.email
            let username = email.components(separatedBy: "@").first ?? ""

            if !username.isEmpty {
                let traders = traderDataService.traders
                if let matchedTrader = traders.first(where: { $0.name.lowercased() == username.lowercased() }) {
                    print("   ✅ Matched trader by username: \(matchedTrader.id)")
                    return matchedTrader.id.uuidString
                }
            }
        }

        return nil
    }

    // MARK: - Private Helpers

    private func fallbackMatchByName(currentUser: User, effectiveTraderId: inout String) -> [Investment] {
        let displayName = "\(currentUser.firstName) \(currentUser.lastName)".trimmingCharacters(in: .whitespaces)
        print("   🔄 Fallback: Trying to match by traderName '\(displayName)'")

        let allInvestments = investmentService.investments
        let matched = allInvestments.filter { investment in
            investment.traderName.caseInsensitiveCompare(displayName) == .orderedSame
        }

        if !matched.isEmpty, let first = matched.first {
            effectiveTraderId = first.traderId
            print("   ✅ Fallback match: Found \(matched.count) investments")
        } else {
            print("   ⚠️ Fallback match failed")
        }

        return matched
    }

    private func filterEligibleInvestments(_ investments: [Investment]) -> [Investment] {
        investments.filter { investment in
            let statusMatch = investment.status == .active
            let reservationMatch = investment.reservationStatus == .reserved ||
                                 investment.reservationStatus == .active ||
                                 investment.reservationStatus == .executing ||
                                 investment.reservationStatus == .closed
            return statusMatch && reservationMatch
        }
    }

    private func applyRoundRobinSelection(_ investments: [Investment]) -> [Investment] {
        let investmentsByInvestor = Dictionary(grouping: investments) { $0.investorId }

        var selectedInvestments: [Investment] = []
        for (_, investorInvestments) in investmentsByInvestor.sorted(by: { $0.key < $1.key }) {
            // Sort by sequence number, then by creation date
            let sorted = investorInvestments.sorted {
                let seq1 = $0.sequenceNumber ?? Int.max
                let seq2 = $1.sequenceNumber ?? Int.max
                if seq1 != seq2 { return seq1 < seq2 }
                return $0.createdAt < $1.createdAt
            }

            if let selected = sorted.first {
                selectedInvestments.append(selected)
            }
        }

        // Sort final list by sequence number
        return selectedInvestments.sorted {
            let seq1 = $0.sequenceNumber ?? Int.max
            let seq2 = $1.sequenceNumber ?? Int.max
            if seq1 != seq2 { return seq1 < seq2 }
            return $0.createdAt < $1.createdAt
        }
    }
}
