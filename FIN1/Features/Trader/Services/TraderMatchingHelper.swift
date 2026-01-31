import Foundation

// MARK: - Trader Matching Helper
/// Provides trader ID matching logic for investment activation
/// Matches users to traders via username, display name, or fuzzy matching
struct TraderMatchingHelper {

    // MARK: - Public API

    /// Finds the trader ID to use for investment matching
    /// First tries to find MockTrader by username from user's email, then falls back to user ID
    /// - Parameters:
    ///   - currentUser: The current authenticated user
    ///   - traderDataService: Service providing trader data
    /// - Returns: Matched trader ID or nil if no match found
    static func findTraderIdForMatching(
        currentUser: User?,
        traderDataService: (any TraderDataServiceProtocol)?
    ) -> String? {
        guard let currentUser = currentUser else {
            print("   ⚠️ TraderMatchingHelper: No current user - cannot find trader ID")
            return nil
        }

        // Extract username from email (e.g., "trader1@test.com" -> "trader1")
        let username = currentUser.email.components(separatedBy: "@").first ?? ""
        print("   🔍 TraderMatchingHelper: Extracted username from email '\(currentUser.email)': '\(username)'")

        // Try to find MockTrader by username
        if let traderDataService = traderDataService {
            // 1) Exact username match
            if let matchedId = matchByUsername(username: username, traderDataService: traderDataService) {
                return matchedId
            }

            // 2) Try display name match
            let displayName = "\(currentUser.firstName) \(currentUser.lastName)".trimmingCharacters(in: .whitespaces)
            if let matchedId = matchByDisplayName(displayName: displayName, traderDataService: traderDataService) {
                return matchedId
            }

            // 3) Fuzzy contains on name as last resort
            if let matchedId = matchByFuzzyName(username: username, traderDataService: traderDataService) {
                return matchedId
            }

            print("   ⚠️ TraderMatchingHelper: No MockTrader found for username/name '\(username)'/'\(displayName)' in \(traderDataService.traders.count) traders")
            print("   📋 Available trader usernames: \(traderDataService.traders.map { $0.username })")
        } else {
            print("   ⚠️ TraderMatchingHelper: traderDataService is nil - cannot lookup by username")
        }

        // Fallback to user ID
        let userId = currentUser.id
        print("   🔄 TraderMatchingHelper: Falling back to user ID: '\(userId)'")
        return userId
    }

    // MARK: - Private Matching Methods

    private static func matchByUsername(
        username: String,
        traderDataService: any TraderDataServiceProtocol
    ) -> String? {
        if let mockTrader = traderDataService.traders.first(where: { $0.username == username }) {
            let traderId = mockTrader.id.uuidString
            print("   ✅ TraderMatchingHelper: Found MockTrader by username '\(username)': ID='\(traderId)'")
            return traderId
        }
        return nil
    }

    private static func matchByDisplayName(
        displayName: String,
        traderDataService: any TraderDataServiceProtocol
    ) -> String? {
        if let byName = traderDataService.traders.first(where: { $0.name.caseInsensitiveCompare(displayName) == .orderedSame }) {
            let traderId = byName.id.uuidString
            print("   ✅ TraderMatchingHelper: Found MockTrader by display name '\(displayName)': ID='\(traderId)'")
            return traderId
        }
        return nil
    }

    private static func matchByFuzzyName(
        username: String,
        traderDataService: any TraderDataServiceProtocol
    ) -> String? {
        if let fuzzy = traderDataService.traders.first(where: { $0.name.localizedCaseInsensitiveContains(username) }) {
            let traderId = fuzzy.id.uuidString
            print("   ✅ TraderMatchingHelper: Found MockTrader by fuzzy name contains '\(username)': ID='\(traderId)'")
            return traderId
        }
        return nil
    }
}











