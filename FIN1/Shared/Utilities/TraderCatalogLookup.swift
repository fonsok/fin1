import Foundation

// MARK: - Trader catalog resolution (InvestorTrader SSOT)

/// Resolves Parse `traderId` for the logged-in trader from `TraderDataService` catalog.
enum TraderCatalogLookup {
    /// Prefer catalog row for `currentUser.id`, then email username, display name, fuzzy name; else `currentUser.id`.
    static func resolveBackendTraderId(
        currentUser: User?,
        traderDataService: (any TraderDataServiceProtocol)?
    ) -> String? {
        guard let currentUser else { return nil }

        if let traderDataService {
            if let byUserId = traderDataService.getTrader(by: currentUser.id) {
                return byUserId.backendTraderId
            }

            let username = currentUser.email.components(separatedBy: "@").first ?? ""
            if !username.isEmpty,
               let byUsername = traderDataService.traders.first(where: { $0.username == username }) {
                return byUsername.backendTraderId
            }

            let displayName = "\(currentUser.firstName) \(currentUser.lastName)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !displayName.isEmpty,
               let byName = traderDataService.traders.first(where: {
                   $0.name.caseInsensitiveCompare(displayName) == .orderedSame
               }) {
                return byName.backendTraderId
            }

            if !username.isEmpty,
               let fuzzy = traderDataService.traders.first(where: {
                   $0.name.localizedCaseInsensitiveContains(username)
               }) {
                return fuzzy.backendTraderId
            }
        }

        return currentUser.id
    }
}
