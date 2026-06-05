import Foundation

/// Resolves **trader** commission for a settled trade from `getTradeSettlement` (SSOT when Gutschrift / timeline rows are missing).
enum TraderCommissionSettlementResolver {
    static func totalCommission(from settlement: TradeSettlementResponse) -> Double {
        let fromCommissionRows = settlement.commissions
            .compactMap(\.commissionAmount)
            .reduce(0, +)
        if fromCommissionRows > 0 {
            return fromCommissionRows
        }

        let fromStatement = settlement.accountStatementEntries
            .filter { $0.entryType == "commission_credit" }
            .reduce(0) { $0 + abs($1.amount) }
        if fromStatement > 0 {
            return fromStatement
        }

        for document in settlement.documents where document.type == DocumentType.traderCreditNote.rawValue {
            if let amount = commissionAmount(from: document.metadata), amount > 0 {
                return amount
            }
        }

        return 0
    }

    private static func commissionAmount(from metadata: BackendDocumentMetadata?) -> Double? {
        guard let metadata else { return nil }
        if let amount = metadata.commissionAmount, amount > 0 { return amount }
        if let amount = metadata.commission, amount > 0 { return amount }
        return nil
    }
}
