import Foundation

enum TraderCollectionBillPartialSellDisplayBuilder {

    static func build(from partial: TraderCollectionBillBelegMetadata.PartialSell?) -> PartialSellDisplayData? {
        guard let partial, partial.showsProgressSection else { return nil }

        let eventIndex = partial.eventIndex
        let totalEvents = partial.totalSellEvents
        let sequenceLabel: String = {
            if let eventIndex, let totalEvents, totalEvents > 0 {
                return "Teilverkauf \(eventIndex) von \(totalEvents)"
            }
            if let eventIndex {
                return "Teilverkauf #\(eventIndex)"
            }
            return "Teilverkauf"
        }()

        let orderQty = partial.orderQuantity ?? partial.soldQuantity ?? 0
        let buyQty = partial.buyQuantity ?? 0
        let cumulative = partial.cumulativeSoldQuantity ?? partial.soldQuantity ?? orderQty
        let remaining = partial.remainingQuantity ?? max(0, buyQty - cumulative)
        let progressPct: String = {
            if let progress = partial.sellVolumeProgress {
                return String(format: "%.1f %%", progress * 100)
            }
            guard buyQty > 0 else { return "—" }
            return String(format: "%.1f %%", min(100, cumulative / buyQty * 100))
        }()

        return PartialSellDisplayData(
            sequenceLabel: sequenceLabel,
            executedAt: self.formatExecutedAt(partial.executedAt),
            sellOrderId: partial.sellOrderId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (partial.sellOrderId ?? "—")
                : "—",
            thisSellQuantity: orderQty > 0 ? "\(Self.formatWholeQuantity(orderQty)) St." : "—",
            cumulativeSold: buyQty > 0
                ? "\(Self.formatWholeQuantity(cumulative)) von \(Self.formatWholeQuantity(buyQty)) St."
                : "—",
            remaining: "\(Self.formatWholeQuantity(remaining)) St.",
            progress: progressPct
        )
    }

    private static func formatWholeQuantity(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    private static func formatExecutedAt(_ raw: String?) -> String {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "—"
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: raw)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: raw)
        }
        guard let date else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy, HH:mm 'Uhr'"
        return formatter.string(from: date)
    }
}
