import Foundation

// MARK: - Trader Collection Bill Beleg Metadata (Parse `Document.metadata` SSOT)

/// Structured GoB beleg payload from `traderCollectionBillBelegSnapshot` (backend SSOT).
struct TraderCollectionBillBelegMetadata: Codable, Equatable, Hashable, Sendable {
    let belegSchemaVersion: Int?
    let belegKind: String?
    let belegLabel: String?
    let traderId: String?
    let traderDisplayName: String?
    let traderUsername: String?
    let executionType: String?
    let symbol: String?
    let instrumentLine: String?
    let amount: Double?
    let quantity: Double?
    let price: Double?
    let orderId: String?
    let sellOrderId: String?
    let wkn: String?
    let fees: Fees?
    let totalWithFees: Double?
    let valueDate: String?
    let closingDate: String?
    let tradingVenue: String?
    let tradeNumber: Int?
    let tradeStatus: String?
    let generatedAt: String?
    let partialSell: PartialSell?

    struct Fees: Codable, Equatable, Hashable, Sendable {
        let orderFee: Double?
        let exchangeFee: Double?
        let foreignCosts: Double?
        let totalFees: Double?
    }

    struct PartialSell: Codable, Equatable, Hashable, Sendable {
        let isPartialSell: Bool?
        let soldQuantity: Double?
        let remainingQuantity: Double?
        let buyQuantity: Double?
    }

    var normalizedExecutionType: String? {
        self.executionType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isSell: Bool { self.normalizedExecutionType == "sell" }
    var isBuy: Bool { self.normalizedExecutionType == "buy" }

    /// Minimum fields required to render structured detail without invoice synthesis.
    var isUsableForDisplay: Bool {
        guard self.isBuy || self.isSell else { return false }
        guard let qty = quantity, qty > 0 else { return false }
        guard let amt = amount, amt > 0 else { return false }
        return true
    }

    var securityIdentifier: String {
        let line = self.instrumentLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !line.isEmpty { return line }
        let sym = self.symbol?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !sym.isEmpty { return sym }
        let w = self.wkn?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return w.isEmpty ? "—" : w
    }
}
