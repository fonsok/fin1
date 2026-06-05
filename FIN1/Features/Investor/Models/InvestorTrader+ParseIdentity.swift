import Foundation

// MARK: - Parse Server identity

extension InvestorTrader {
    var backendTraderId: String {
        if let parseUserId = self.parseUserId, !parseUserId.isEmpty {
            return parseUserId
        }
        return self.catalogId
    }

    var hasParseUserId: Bool {
        guard let parseUserId = self.parseUserId, !parseUserId.isEmpty else { return false }
        return TraderParseIdentity.isLikelyParseObjectId(parseUserId)
    }

    func withParseUserId(_ parseUserId: String?) -> InvestorTrader {
        InvestorTrader(
            catalogId: self.catalogId,
            parseUserId: parseUserId,
            name: self.name,
            username: self.username,
            specialization: self.specialization,
            experienceYears: self.experienceYears,
            isVerified: self.isVerified,
            riskLevel: self.riskLevel,
            demoMetrics: self.demoMetrics,
            isFromMockCatalog: self.isFromMockCatalog
        )
    }
}

/// Shared Parse id heuristics (MockTrader + InvestorTrader).
enum TraderParseIdentity {
    static func isLikelyParseObjectId(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (8...12).contains(trimmed.count) else { return false }
        if trimmed.contains("-") { return false }
        return trimmed.range(of: "^[A-Za-z0-9]+$", options: .regularExpression) != nil
    }
}
