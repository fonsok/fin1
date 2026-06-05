import Foundation

// MARK: - Trader Matching Helper
/// Resolves Parse trader id for buy-order / profit / activation flows via `InvestorTrader` catalog.
struct TraderMatchingHelper {

    /// Finds the trader ID to use for investment matching (Parse `objectId` when catalog is hydrated).
    static func findTraderIdForMatching(
        currentUser: User?,
        traderDataService: (any TraderDataServiceProtocol)?
    ) -> String? {
        guard let currentUser else {
            print("   ⚠️ TraderMatchingHelper: No current user")
            return nil
        }

        if let traderDataService,
           let byUserId = traderDataService.getTrader(by: currentUser.id) {
            print("   ✅ TraderMatchingHelper: catalog by user.id → \(byUserId.backendTraderId)")
            return byUserId.backendTraderId
        }

        let resolved = TraderCatalogLookup.resolveBackendTraderId(
            currentUser: currentUser,
            traderDataService: traderDataService
        )
        if let resolved {
            print("   ✅ TraderMatchingHelper: resolved → \(resolved)")
        }
        return resolved
    }
}
