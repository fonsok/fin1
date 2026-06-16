import Foundation

/// Resolves investor display labels for trader commission breakdown rows.
enum TradeInvestorCommissionNameResolver {

    static func resolve(
        serverName: String? = nil,
        investmentId: String?,
        investorId: String?,
        investments: [Investment]
    ) -> String {
        let fromServer = serverName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromServer.isEmpty { return fromServer }

        if let investmentId, !investmentId.isEmpty,
           let name = investmentName(from: investments, investmentId: investmentId) {
            return name
        }

        if let investorId, !investorId.isEmpty,
           let name = investmentName(from: investments, investorId: investorId) {
            return name
        }

        if let label = displayNameFromInvestorId(investorId) {
            return label
        }

        return String(localized: "Investor", comment: "Fallback when investor display name unavailable")
    }

    private static func investmentName(from investments: [Investment], investmentId: String) -> String? {
        guard let investment = investments.first(where: { $0.id == investmentId }) else { return nil }
        return self.displayName(from: investment)
    }

    private static func investmentName(from investments: [Investment], investorId: String) -> String? {
        guard let investment = investments.first(where: { $0.investorId == investorId }) else { return nil }
        return self.displayName(from: investment)
    }

    private static func displayName(from investment: Investment) -> String? {
        let username = investment.investorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !username.isEmpty { return username }
        let number = investment.investmentNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return number.isEmpty ? nil : number
    }

    private static func displayNameFromInvestorId(_ investorId: String?) -> String? {
        guard let investorId, investorId.hasPrefix("user:") else { return nil }
        let raw = String(investorId.dropFirst("user:".count))
        let base = raw.split(separator: "@").first.map(String.init) ?? raw
        let label = base.replacingOccurrences(of: ".", with: " ")
        return label.isEmpty ? nil : label
    }
}
