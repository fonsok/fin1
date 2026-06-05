import Foundation

extension Document {

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
            documentNumber: backend.accountingDocumentNumber
        )
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
