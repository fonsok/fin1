import Foundation

// MARK: - Local SSOT drift (snapshot text vs structured metadata)

extension Document {

    enum TraderBelegDriftField: String, Equatable {
        case quantity
        case executionType
        case amount
        case totalWithFees
    }

    /// Compares persisted `accountingSummaryText` with `traderCollectionBillMetadata` (client-side guard).
    func traderBelegSnapshotMetadataDrifts() -> [TraderBelegDriftField] {
        Self.traderBelegSnapshotMetadataDrifts(
            snapshotText: accountingSummaryText,
            metadata: traderCollectionBillMetadata
        )
    }

    static func traderBelegSnapshotMetadataDrifts(
        snapshotText: String?,
        metadata: TraderCollectionBillBelegMetadata?
    ) -> [TraderBelegDriftField] {
        guard let meta = metadata, meta.isUsableForDisplay else { return [] }
        guard let text = snapshotText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return []
        }

        var drifts: [TraderBelegDriftField] = []

        if let snapQty = Self.traderBelegOrderQuantity(fromSnapshotText: text),
           let metaQty = meta.quantity,
           snapQty != Int(metaQty) {
            drifts.append(.quantity)
        }

        let snapIsSell = text.localizedCaseInsensitiveContains("verkaufsabrechnung")
            || text.contains("\nVERKAUF\n")
            || text.contains("Σ VERKAUF")
        let snapIsBuy = text.localizedCaseInsensitiveContains("kaufabrechnung")
            || text.contains("\nKAUF\n")
            || text.contains("Σ KAUF")
        if meta.isSell && !snapIsSell { drifts.append(.executionType) }
        if meta.isBuy && !snapIsBuy && snapIsSell { drifts.append(.executionType) }

        if let snapAmount = Self.traderBelegEuroAmount(fromSnapshotText: text, label: "Kurswert"),
           let metaAmount = meta.amount?.doubleValue,
           abs(snapAmount - metaAmount) > 0.02 {
            drifts.append(.amount)
        }

        if let snapTotal = Self.traderBelegSigmaTotal(fromSnapshotText: text),
           let metaTotal = meta.totalWithFees?.doubleValue,
           abs(snapTotal - metaTotal) > 0.02 {
            drifts.append(.totalWithFees)
        }

        return drifts
    }

    static func traderBelegEuroAmount(fromSnapshotText text: String, label: String) -> Double? {
        let pattern = #"\#(label):\s*(-?[\d.]+,\d{2}|-?\d+(?:,\d+)?)\s*€"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Self.parseGermanEuroNumber(String(text[range]))
    }

    static func traderBelegSigmaTotal(fromSnapshotText text: String) -> Double? {
        let pattern = #"Σ\s+(?:KAUF|VERKAUF):\s*(-?[\d.]+,\d{2}|-?\d+(?:,\d+)?)\s*€"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return abs(Self.parseGermanEuroNumber(String(text[range])) ?? 0)
    }

    private static func parseGermanEuroNumber(_ raw: String) -> Double? {
        let normalized = raw
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}
