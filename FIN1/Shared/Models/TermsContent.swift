import Foundation

// MARK: - Server-Driven Legal Content Models

/// Mirrors the Parse Cloud Function response for `getCurrentTerms`
struct TermsContent: Codable, Hashable {
    let objectId: String?
    let version: String
    let language: String
    let documentType: String
    let effectiveDate: String?
    let isActive: Bool
    let documentHash: String?
    let sections: [TermsContentSection]
    let createdAt: String?
    let updatedAt: String?
}

struct TermsContentSection: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let content: String
    let icon: String?
}

enum LegalDocumentType: String, Codable, CaseIterable {
    case terms = "terms"
    case privacy = "privacy"
    case imprint = "imprint"
}

