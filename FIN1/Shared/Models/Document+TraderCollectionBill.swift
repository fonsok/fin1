import Foundation

// MARK: - Trader TBC/TSC presentation helpers

extension Document {

    enum TraderBelegExecutionSide: String, Equatable {
        case buy
        case sell

        var navigationTitle: String {
            switch self {
            case .buy: return "Kaufabrechnung"
            case .sell: return "Verkaufsabrechnung"
            }
        }

        var invoiceComparisonNavigationTitle: String {
            switch self {
            case .buy: return "Kaufabrechnung (Rechnung)"
            case .sell: return "Verkaufsabrechnung (Rechnung)"
            }
        }
    }

    /// Inferred from GoB metadata, prefix (`TBC-` / `TSC-`), or snapshot heading.
    var traderBelegExecutionSide: TraderBelegExecutionSide? {
        guard self.type == .traderCollectionBill else { return nil }

        if let meta = traderCollectionBillMetadata {
            if meta.isSell { return .sell }
            if meta.isBuy { return .buy }
        }

        let accNo = (self.accountingDocumentNumber ?? "").uppercased()
        if accNo.hasPrefix("TSC-") { return .sell }
        if accNo.hasPrefix("TBC-") { return .buy }

        let summary = (self.accountingSummaryText ?? "").lowercased()
        if summary.contains("verkaufsabrechnung") || summary.contains("σ verkauf") {
            return .sell
        }
        if summary.contains("kaufabrechnung") || summary.contains("σ kauf") {
            return .buy
        }

        let name = self.name.lowercased()
        if name.contains("verkaufsabrechnung") { return .sell }
        if name.contains("kaufabrechnung") { return .buy }
        return nil
    }

    var traderBelegNavigationTitle: String {
        self.traderBelegExecutionSide?.navigationTitle ?? "Abrechnung"
    }

    /// True when Parse `accountingSummaryText` is sufficient for Phase-1 Beleg snapshot display.
    static func isUsableTraderBelegSnapshotText(_ text: String?) -> Bool {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return false }
        return trimmed.contains("Belegnummer")
            || trimmed.contains("Ordervolumen")
            || trimmed.contains("Σ KAUF")
            || trimmed.contains("Σ VERKAUF")
            || trimmed.contains("Kaufabrechnung")
            || trimmed.contains("Verkaufsabrechnung")
    }

    /// Trader TSC/TBC rows in the local cache need a Parse refetch when SSOT text/metadata is missing.
    var needsTraderBelegSnapshotRefresh: Bool {
        guard self.type == .traderCollectionBill else { return false }
        if Self.isUsableTraderBelegSnapshotText(self.accountingSummaryText) { return false }
        if self.traderCollectionBillMetadata?.isUsableForDisplay == true { return false }
        return true
    }

    /// Parses `Ordervolumen: 400 St.` from backend `accountingSummaryText`, or structured metadata.
    var traderBelegOrderQuantityFromSnapshot: Int? {
        if let qty = traderCollectionBillMetadata?.quantity, qty > 0 {
            return Int(qty)
        }
        guard let text = self.accountingSummaryText else { return nil }
        return Self.traderBelegOrderQuantity(fromSnapshotText: text)
    }

    static func traderBelegOrderQuantity(fromSnapshotText text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let pattern = #"Ordervolumen:\s*(\d+)\s*St"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: trimmed) else {
            return nil
        }
        return Int(trimmed[range])
    }
}
