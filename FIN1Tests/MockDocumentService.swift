import Foundation
import Combine
@testable import FIN1

// MARK: - Mock Document Service (Simplified)
/// Simplified mock using closure-based behavior instead of multiple configuration properties
class MockDocumentService: DocumentServiceProtocol {
    @Published var documents: [Document] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    var documentsPublisher: AnyPublisher<[Document], Never> {
        $documents.eraseToAnyPublisher()
    }

    // MARK: - Behavior Closures (Simplified Approach)
    /// Closure to handle uploadDocument - defaults to appending to documents array
    var uploadDocumentHandler: ((Document) async throws -> Void)?

    /// Closure to handle deleteDocument - defaults to removing from documents array
    var deleteDocumentHandler: ((Document) async throws -> Void)?

    /// Closure to handle downloadDocument - defaults to simple mock data
    var downloadDocumentHandler: ((Document) async throws -> Data)?

    // MARK: - Document Management
    func loadDocuments(for user: User) {
        // no-op in mock; tests set documents directly
    }

    func uploadDocument(_ document: Document) async throws {
        if let handler = uploadDocumentHandler {
            try await handler(document)
        } else {
            // Default: append to documents
            await MainActor.run { self.documents.append(document) }
        }
    }

    func deleteDocument(_ document: Document) async throws {
        if let handler = deleteDocumentHandler {
            try await handler(document)
        } else {
            // Default: remove from documents
            await MainActor.run { self.documents.removeAll { $0.id == document.id } }
        }
    }

    func downloadDocument(_ document: Document) async throws -> Data {
        if let handler = downloadDocumentHandler {
            return try await handler(document)
        } else {
            // Default: simple mock data
            return Data("Mock document content".utf8)
        }
    }

    // MARK: - Queries
    func getDocuments(for userId: String) -> [Document] {
        documents.filter { $0.userId == userId }
    }

    func getDocumentsByType(_ type: DocumentType, for userId: String) -> [Document] {
        documents.filter { $0.userId == userId && $0.type == type }
    }

    func getDocument(by id: String) -> Document? {
        documents.first { $0.id == id }
    }

    func getDocumentsForTrade(_ tradeId: String) -> [Document] {
        documents.filter { $0.tradeId == tradeId }
    }

    func getDocumentsForInvestment(_ investmentId: String) -> [Document] {
        documents.filter { $0.investmentId == investmentId }
    }

    func documentExists(for tradeId: String, ofType type: DocumentType) -> Bool {
        documents.contains { $0.tradeId == tradeId && $0.type == type }
    }

    func documentExists(forInvestmentId investmentId: String, ofType type: DocumentType) -> Bool {
        documents.contains { $0.investmentId == investmentId && $0.type == type }
    }

    // MARK: - Validation & Status
    func validateDocument(_ document: Document) -> Bool {
        !document.name.isEmpty && !document.fileURL.isEmpty && document.size > 0
    }

    func getDocumentStatus(for document: Document) -> DocumentStatus {
        document.status
    }

    // MARK: - Status Management
    func markAllDocumentsAsRead() {
        for idx in documents.indices { documents[idx].readAt = Date() }
    }

    func markDocumentAsRead(_ document: Document) {
        if let idx = documents.firstIndex(where: { $0.id == document.id }) {
            documents[idx].readAt = Date()
        }
    }

    // MARK: - Backend Synchronization

    func syncToBackend() async {
        // Mock: no-op
    }

    // MARK: - ServiceLifecycle

    func start() {}
    func stop() {}

    func reset() {
        documents.removeAll()
        isLoading = false
        errorMessage = nil
        showError = false
        // Reset all handlers
        uploadDocumentHandler = nil
        deleteDocumentHandler = nil
        downloadDocumentHandler = nil
    }
}
