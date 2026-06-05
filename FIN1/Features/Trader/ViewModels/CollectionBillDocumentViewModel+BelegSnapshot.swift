import Foundation

// MARK: - Trader TBC: Parse Document SSOT (accountingSummaryText)

@MainActor
extension CollectionBillDocumentViewModel {
    /// True wenn Phase-1-Snapshot-Anzeige statt `TradeStatementView` genutzt werden soll.
    var prefersSnapshotBelegDisplay: Bool {
        Self.isUsableTraderBelegSnapshot(self.resolvedBelegSnapshotText)
    }

    static func isUsableTraderBelegSnapshot(_ text: String?) -> Bool {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return false }
        return trimmed.contains("Belegnummer")
            || trimmed.contains("Ordervolumen")
            || trimmed.contains("Σ KAUF")
            || trimmed.contains("Σ VERKAUF")
            || trimmed.contains("Kaufabrechnung")
            || trimmed.contains("Verkaufsabrechnung")
    }

    func refreshTraderBelegSnapshotFromServer() async {
        guard self.routingDocument.type == .traderCollectionBill else {
            self.resolvedBelegSnapshotText = nil
            return
        }

        var merged = self.routingDocument
        do {
            let fetched = try await self.documentService.resolveDocumentForDeepLink(objectId: merged.id)
            merged = fetched
            self.canonicalDocument = fetched
        } catch {
            print(
                "⚠️ CollectionBillDocumentViewModel: fetchDocument for Beleg SSOT failed: "
                    + error.localizedDescription
            )
        }

        if Self.isUsableTraderBelegSnapshot(merged.accountingSummaryText) {
            self.resolvedBelegSnapshotText = merged.accountingSummaryText
            print("✅ CollectionBillDocumentViewModel: Parse accountingSummaryText SSOT (\(merged.id))")
            return
        }

        do {
            let enriched = try await self.documentService.fetchTraderBelegDetailEnriched(objectId: merged.id)
            self.canonicalDocument = enriched
            if Self.isUsableTraderBelegSnapshot(enriched.accountingSummaryText) {
                self.resolvedBelegSnapshotText = enriched.accountingSummaryText
                print("✅ CollectionBillDocumentViewModel: Cloud getTraderDocumentBelegDetail SSOT (\(merged.id))")
                return
            }
        } catch {
            print(
                "⚠️ CollectionBillDocumentViewModel: getTraderDocumentBelegDetail failed: "
                    + error.localizedDescription
            )
        }

        self.resolvedBelegSnapshotText = nil
        print("ℹ️ CollectionBillDocumentViewModel: no SSOT snapshot — fallback to TradeStatement/Invoice")
    }
}
