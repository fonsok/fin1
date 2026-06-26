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
        #if DEBUG
        print("🔍 BuyOrderInvestmentDataProvider: Fetching reserved investments")
        #endif

        guard let currentUser = currentUser else {
            #if DEBUG
            print("   ❌ No current user")
            #endif
            return []
        }

        guard currentUser.role == .trader else {
            #if DEBUG
            print("   ❌ User is not a trader")
            #endif
            return []
        }

        // Use provided traderId or find one
        var effectiveTraderId = traderId ?? self.findTraderIdForMatching(currentUser: currentUser) ?? currentUser.id
        #if DEBUG
        print("   📊 Using trader ID: \(effectiveTraderId)")
        #endif

        // Get ALL investments for this trader
        var allTraderInvestments = self.investmentService.getInvestments(forTrader: effectiveTraderId)
        #if DEBUG
        print("   📊 Total investments for trader: \(allTraderInvestments.count)")
        #endif

        // FALLBACK: If no investments found and traderDataService is nil, try matching by name
        if allTraderInvestments.isEmpty && self.traderDataService == nil {
            allTraderInvestments = self.fallbackMatchByName(currentUser: currentUser, effectiveTraderId: &effectiveTraderId)
        }

        // Filter investments - match BuyOrderInvestmentCalculator logic
        let filteredInvestments = self.filterEligibleInvestments(allTraderInvestments)
        #if DEBUG
        print("   📊 Filtered to \(filteredInvestments.count) eligible investments")
        #endif

        // Apply Round Robin: Select ONE investment per investor
        let selectedInvestments = self.applyRoundRobinSelection(filteredInvestments)
        #if DEBUG
        print("   ✅ Selected \(selectedInvestments.count) investments (Round Robin)")
        #endif

        return selectedInvestments
    }

    func findTraderIdForMatching(currentUser: User?) -> String? {
        TraderMatchingHelper.findTraderIdForMatching(
            currentUser: currentUser,
            traderDataService: self.traderDataService
        )
    }

    // MARK: - Private Helpers

    private func fallbackMatchByName(currentUser: User, effectiveTraderId: inout String) -> [Investment] {
        let displayName = "\(currentUser.firstName) \(currentUser.lastName)".trimmingCharacters(in: .whitespaces)
        #if DEBUG
        print("   🔄 Fallback: Trying to match by traderName '\(displayName)'")
        #endif

        let allInvestments = self.investmentService.investments
        let matched = allInvestments.filter { investment in
            investment.traderName.caseInsensitiveCompare(displayName) == .orderedSame
        }

        if !matched.isEmpty, let first = matched.first {
            effectiveTraderId = first.traderId
            #if DEBUG
            print("   ✅ Fallback match: Found \(matched.count) investments")
            #endif
        } else {
            #if DEBUG
            print("   ⚠️ Fallback match failed")
            #endif
        }

        return matched
    }

    private func filterEligibleInvestments(_ investments: [Investment]) -> [Investment] {
        investments.filter(\.hasPoolCapitalCommitted)
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
