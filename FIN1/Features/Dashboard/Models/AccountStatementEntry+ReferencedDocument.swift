import Foundation

extension AccountStatementEntry {
    /// Resolves the `Document` row for a statement line that carries a Beleg reference.
    /// 1. Direct id (`referenceDocumentId`) – matches Document.objectId.
    /// 2. Direct accounting number (`referenceDocumentNumber`).
    /// 3. Fallback for trade settlement rows: match by `tradeId` + transaction direction
    ///    (Kauf-/Verkaufabrechnung) so the link works even when older backend snapshots
    ///    didn't yet store the canonical Document refs on the AccountStatement entry.
    func referencedDocument(documentService: any DocumentServiceProtocol) -> Document? {
        let docId = referenceDocumentId ?? metadata["referenceDocumentId"]
        if let docId, !docId.isEmpty,
           let byId = documentService.getDocument(by: docId) {
            return byId
        }

        let docNumber = referenceDocumentNumber ?? metadata["referenceDocumentNumber"]
        if let docNumber, !docNumber.isEmpty,
           let byNumber = documentService.documents.first(where: { $0.accountingDocumentNumber == docNumber }) {
            return byNumber
        }

        guard category == .tradeSettlement,
              let tradeId = metadata["tradeId"], !tradeId.isEmpty,
              let txType = metadata["transactionType"], !txType.isEmpty else {
            return nil
        }

        let candidates = documentService.documents
            .filter { $0.tradeId == tradeId && $0.type == .traderCollectionBill }
        let prefix = txType == "buy" ? "Kauf" : "Verkauf"
        return candidates.first(where: { $0.name.lowercased().hasPrefix(prefix.lowercased()) })
            ?? candidates.first
    }

    /// Robust resolver: same fallback chain as `referencedDocument`, but if the local
    /// `documentService.documents` cache misses (race / partial fetch / role-specific
    /// `Document` types not yet pulled into the trader DocumentService), fall back to a
    /// direct Parse fetch by `referenceDocumentId`. Used by the AccountStatement tap
    /// handler so trader Belegnr.-Links don't silently fail with a missing-document alert
    /// when the data clearly exists server-side.
    @MainActor
    func resolveReferencedDocument(documentService: any DocumentServiceProtocol) async -> Document? {
        if let cached = referencedDocument(documentService: documentService) {
            return cached
        }

        let docId = referenceDocumentId ?? metadata["referenceDocumentId"]
        if let docId, !docId.isEmpty {
            do {
                return try await documentService.resolveDocumentForDeepLink(objectId: docId)
            } catch {
                print("⚠️ AccountStatementEntry: resolveDocumentForDeepLink failed for \(docId): \(error.localizedDescription)")
            }
        }

        return nil
    }
}
