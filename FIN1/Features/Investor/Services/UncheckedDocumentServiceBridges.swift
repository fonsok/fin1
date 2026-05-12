import Foundation

// MARK: - Unchecked bridges (Swift 6 strict concurrency)
/// `DocumentServiceProtocol` and `InvestmentDocumentServiceProtocol` are not `Sendable`, but investment
/// creation runs on the main actor and these services are main-thread bound in production.

final class UncheckedDocumentServiceBridge: @unchecked Sendable {
    private let documentService: any DocumentServiceProtocol

    init(documentService: any DocumentServiceProtocol) {
        self.documentService = documentService
    }

    func uploadDocument(_ document: Document) async throws {
        try await documentService.uploadDocument(document)
    }
}

final class UncheckedInvestmentDocumentServiceBridge: @unchecked Sendable {
    private let service: any InvestmentDocumentServiceProtocol

    init(_ service: any InvestmentDocumentServiceProtocol) {
        self.service = service
    }

    func generateInvestmentDocument(for batch: InvestmentBatch, investments: [Investment]) async {
        await service.generateInvestmentDocument(for: batch, investments: investments)
    }
}
