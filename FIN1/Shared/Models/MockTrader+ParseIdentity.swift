import Foundation

// MARK: - Parse Server identity (SSOT for investments / pool mirror)

extension MockTrader {
    /// Parse `_User.objectId` when hydrated from `discoverTraders`; `nil` in offline-only mock mode.
    var parseUserId: String? { self._parseUserId }

    /// Id for API calls and `Investment.traderId` — never a random Mock UUID when Parse id is known.
    var backendTraderId: String {
        if let parseUserId = _parseUserId, !parseUserId.isEmpty {
            return parseUserId
        }
        return self.id.uuidString
    }

    var hasParseUserId: Bool {
        guard let parseUserId = _parseUserId, !parseUserId.isEmpty else { return false }
        return TraderParseIdentity.isLikelyParseObjectId(parseUserId)
    }

    func withParseUserId(_ parseUserId: String?) -> MockTrader {
        MockTrader(
            id: self.id,
            parseUserId: parseUserId,
            name: self.name,
            username: self.username,
            specialization: self.specialization,
            experienceYears: self.experienceYears,
            isVerified: self.isVerified,
            performance: self.performance,
            totalTrades: self.totalTrades,
            winRate: self.winRate,
            averageReturn: self.averageReturn,
            totalReturn: self.totalReturn,
            riskLevel: self.riskLevel,
            recentTrades: self.recentTrades,
            lastNTrades: self.lastNTrades,
            successfulTradesInLastN: self.successfulTradesInLastN,
            averageReturnLastNTrades: self.averageReturnLastNTrades,
            consecutiveWinningTrades: self.consecutiveWinningTrades,
            maxDrawdown: self.maxDrawdown,
            sharpeRatio: self.sharpeRatio
        )
    }
}
