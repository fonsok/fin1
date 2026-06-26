import Foundation
import SwiftUI

@MainActor
final class RoleAgreementStepViewModel: ObservableObject {
    @Published private(set) var sections: [TermsContentSection] = []
    @Published private(set) var documentVersion: String = "1.0"
    @Published private(set) var documentHash: String?
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?
    @Published var hasScrolledToBottom = false
    @Published var isCheckboxChecked = false
    @Published var isSubmitting = false
    @Published var submitError: String?

    let role: UserRole
    private let termsContentService: (any TermsContentServiceProtocol)?
    private let roleAgreementConsentService: (any RoleAgreementConsentServiceProtocol)?

    var title: String { RoleAgreementBundledContent.title(for: self.role) }

    var canSubmit: Bool {
        self.hasScrolledToBottom && self.isCheckboxChecked && !self.isSubmitting
    }

    init(
        role: UserRole,
        termsContentService: (any TermsContentServiceProtocol)?,
        roleAgreementConsentService: (any RoleAgreementConsentServiceProtocol)?
    ) {
        self.role = role
        self.termsContentService = termsContentService
        self.roleAgreementConsentService = roleAgreementConsentService
    }

    func loadDocument() async {
        self.isLoading = true
        self.loadError = nil
        self.hasScrolledToBottom = false
        self.isCheckboxChecked = false

        guard let documentType = LegalDocumentType.roleAgreement(for: self.role) else {
            self.sections = []
            self.isLoading = false
            return
        }

        let language: TermsOfServiceDataProvider.Language = .german

        if let cached = termsContentService?.getCachedTerms(language: language, documentType: documentType) {
            self.apply(content: cached)
        }

        if let termsContentService {
            do {
                let fetched = try await termsContentService.fetchCurrentTerms(
                    language: language,
                    documentType: documentType
                )
                termsContentService.cacheTerms(fetched, language: language, documentType: documentType)
                self.apply(content: fetched)
                await termsContentService.logDelivery(
                    documentType: documentType,
                    language: language,
                    servedVersion: fetched.version,
                    servedHash: fetched.documentHash,
                    source: "server"
                )
            } catch {
                if self.sections.isEmpty {
                    self.loadError = error.localizedDescription
                    self.sections = RoleAgreementBundledContent.sections(for: self.role)
                    self.documentVersion = "bundled"
                    self.documentHash = nil
                }
            }
        } else if self.sections.isEmpty {
            self.sections = RoleAgreementBundledContent.sections(for: self.role)
            self.documentVersion = "bundled"
        }

        self.isLoading = false
    }

    func recordConsentAndReturn() async throws {
        guard self.canSubmit else { return }
        guard let roleAgreementConsentService else {
            throw AppError.serviceError(.serviceUnavailable)
        }

        self.isSubmitting = true
        self.submitError = nil
        defer { self.isSubmitting = false }

        do {
            try await roleAgreementConsentService.recordConsent(
                role: self.role,
                version: self.documentVersion,
                documentHash: self.documentHash,
                source: "onboarding",
                sendConfirmationEmail: true
            )
        } catch {
            self.submitError = error.localizedDescription
            throw error
        }
    }

    private func apply(content: TermsContent) {
        self.sections = content.sections
        self.documentVersion = content.version
        self.documentHash = content.documentHash
    }
}
