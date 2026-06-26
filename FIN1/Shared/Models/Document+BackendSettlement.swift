import Foundation

extension Document {

    /// Maps backend settlement rows to inbox-eligible `Document` rows (excludes internal GoB eigenbelege).
    static func inboxEligible(from backendDocuments: [BackendSettlementDocument]) -> [Document] {
        backendDocuments
            .filter { !DocumentInboxPolicy.isInternalBackendDocumentType($0.type) }
            .map { Document(backendSettlementDocument: $0) }
            .filter { DocumentInboxPolicy.isDisplayableInNotificationsInbox($0) }
    }

    init(backendSettlementDocument backend: BackendSettlementDocument) {
        let title = backend.accountingDocumentNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (title?.isEmpty == false) ? title! : backend.name
        self.init(
            id: backend.objectId,
            userId: backend.userId,
            name: displayName,
            type: DocumentType(rawValue: backend.type) ?? .other,
            status: .verified,
            fileURL: "",
            size: 0,
            uploadedAt: Date(),
            tradeId: backend.tradeId,
            investmentId: backend.investmentId,
            documentNumber: backend.accountingDocumentNumber,
            accountingSummaryText: backend.accountingSummaryText,
            traderCollectionBillMetadata: backend.traderCollectionBillMetadata
        )
    }

    /// Keeps GoB SSOT fields when settlement sync merges a sparse row over a richer inbox cache entry.
    static func mergedPreservingTraderBelegSSOT(existing: Document, incoming: Document) -> Document {
        let summary = Self.preferredNonEmptyText(incoming.accountingSummaryText, existing.accountingSummaryText)
        let metadata: TraderCollectionBillBelegMetadata? = {
            if incoming.traderCollectionBillMetadata?.isUsableForDisplay == true {
                return incoming.traderCollectionBillMetadata
            }
            if existing.traderCollectionBillMetadata?.isUsableForDisplay == true {
                return existing.traderCollectionBillMetadata
            }
            return incoming.traderCollectionBillMetadata ?? existing.traderCollectionBillMetadata
        }()
        let displayName = incoming.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? existing.name
            : incoming.name
        return Document(
            id: incoming.id,
            userId: incoming.userId.isEmpty ? existing.userId : incoming.userId,
            name: displayName,
            type: incoming.type,
            status: incoming.status,
            fileURL: Self.preferredNonEmptyText(incoming.fileURL, existing.fileURL) ?? "",
            size: incoming.size > 0 ? incoming.size : existing.size,
            uploadedAt: incoming.uploadedAt,
            verifiedAt: incoming.verifiedAt ?? existing.verifiedAt,
            expiresAt: incoming.expiresAt ?? existing.expiresAt,
            invoiceData: existing.invoiceData,
            tradeId: incoming.tradeId ?? existing.tradeId,
            tradeNumber: incoming.tradeNumber ?? existing.tradeNumber,
            investmentId: incoming.investmentId ?? existing.investmentId,
            statementYear: incoming.statementYear ?? existing.statementYear,
            statementMonth: incoming.statementMonth ?? existing.statementMonth,
            statementRole: incoming.statementRole ?? existing.statementRole,
            documentNumber: Self.preferredNonEmptyText(
                incoming.documentNumber,
                existing.documentNumber
            ),
            traderCommissionRateSnapshot: incoming.traderCommissionRateSnapshot
                ?? existing.traderCommissionRateSnapshot,
            accountingSummaryText: summary,
            traderCollectionBillMetadata: metadata
        )
    }

    private static func preferredNonEmptyText(_ primary: String?, _ fallback: String?) -> String? {
        let trimmedPrimary = primary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedPrimary.isEmpty { return trimmedPrimary }
        let trimmedFallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedFallback.isEmpty ? nil : trimmedFallback
    }

    init(backendCollectionBill backend: BackendCollectionBill) {
        let typeRaw = backend.type ?? DocumentType.investorCollectionBill.rawValue
        let title = backend.accountingDocumentNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (title?.isEmpty == false) ? title! : "Collection Bill"
        self.init(
            id: backend.objectId,
            userId: backend.userId ?? "",
            name: displayName,
            type: DocumentType(rawValue: typeRaw) ?? .investorCollectionBill,
            status: .verified,
            fileURL: "",
            size: 0,
            uploadedAt: Self.parseBackendCreatedAt(backend.createdAt) ?? Date(),
            tradeId: backend.tradeId,
            investmentId: backend.investmentId,
            documentNumber: backend.accountingDocumentNumber
        )
    }

    private static func parseBackendCreatedAt(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}
