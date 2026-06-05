import Foundation

extension InvestmentService {
    /// Parse `_User.username` when `traderId` is still a local MockTrader UUID (background / stale pending).
    /// - Parameter explicit: Caller override (e.g. user-initiated create with known trader).
    func traderUsernameForSync(investment: Investment, explicit: String? = nil) -> String? {
        let stored = investment.storedTraderUsername
        if !stored.isEmpty { return stored }
        return self.traderUsernameForSync(traderId: investment.traderId, explicit: explicit)
    }

    func traderUsernameForSync(traderId: String, explicit: String? = nil) -> String? {
        if let explicit, !explicit.isEmpty {
            return explicit
        }
        let id = traderId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }
        if TraderParseIdentity.isLikelyParseObjectId(id) {
            return nil
        }
        guard let traderDataService else { return nil }
        guard let trader = traderDataService.getTrader(by: id) else { return nil }
        let username = trader.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return username.isEmpty ? nil : username
    }
}
