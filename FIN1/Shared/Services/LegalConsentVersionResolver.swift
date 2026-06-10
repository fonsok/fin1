import Foundation

/// Single source of truth for resolving active legal document versions for consent gating.
enum LegalConsentVersionResolver {

    struct ResolvedDocuments {
        let termsVersion: String
        let privacyVersion: String
        let termsHash: String?
        let privacyHash: String?
    }

    static func resolveDocuments(
        user: User,
        termsContentService: (any TermsContentServiceProtocol)?
    ) async -> ResolvedDocuments {
        let termsLanguage = self.termsLanguage()
        let privacyLanguage = self.privacyLanguage(for: user)

        let terms = await self.resolveContent(
            user: user,
            documentType: .terms,
            language: termsLanguage,
            termsContentService: termsContentService
        )
        let privacy = await self.resolveContent(
            user: user,
            documentType: .privacy,
            language: privacyLanguage,
            termsContentService: termsContentService
        )

        return ResolvedDocuments(
            termsVersion: terms.version,
            privacyVersion: privacy.version,
            termsHash: terms.hash,
            privacyHash: privacy.hash
        )
    }

    static func resolveVersion(
        user: User,
        documentType: LegalDocumentType,
        termsContentService: (any TermsContentServiceProtocol)?
    ) async -> String {
        let language: TermsOfServiceDataProvider.Language = switch documentType {
        case .terms: self.termsLanguage()
        case .privacy: self.privacyLanguage(for: user)
        case .imprint: .german
        }
        return await self.resolveContent(
            user: user,
            documentType: documentType,
            language: language,
            termsContentService: termsContentService
        ).version
    }

    // MARK: - Private

    private struct ResolvedContent {
        let version: String
        let hash: String?
    }

    private static func termsLanguage() -> TermsOfServiceDataProvider.Language {
        Locale.current.language.languageCode?.identifier == "de" ? .german : .english
    }

    private static func privacyLanguage(for user: User) -> TermsOfServiceDataProvider.Language {
        let jurisdiction = PrivacyPolicyDataProvider.determineJurisdiction(
            country: user.country,
            nationality: user.nationality,
            isNotUSCitizen: user.isNotUSCitizen
        )
        return jurisdiction == .american ? .english : .german
    }

    private static func resolveContent(
        user: User,
        documentType: LegalDocumentType,
        language: TermsOfServiceDataProvider.Language,
        termsContentService: (any TermsContentServiceProtocol)?
    ) async -> ResolvedContent {
        if let termsContentService {
            if let cached = termsContentService.getCachedTerms(language: language, documentType: documentType) {
                let version = cached.version.trimmingCharacters(in: .whitespacesAndNewlines)
                if !version.isEmpty {
                    return ResolvedContent(version: version, hash: cached.documentHash)
                }
            }
            if let fetched = try? await termsContentService.fetchCurrentTerms(
                language: language,
                documentType: documentType
            ) {
                let version = fetched.version.trimmingCharacters(in: .whitespacesAndNewlines)
                if !version.isEmpty {
                    return ResolvedContent(version: version, hash: fetched.documentHash)
                }
            }
        }

        if let profileVersion = self.acceptedVersion(from: user, documentType: documentType) {
            return ResolvedContent(version: profileVersion, hash: nil)
        }

        let fallback = self.bundledFallbackVersion(documentType: documentType)
        return ResolvedContent(version: fallback, hash: nil)
    }

    private static func acceptedVersion(from user: User, documentType: LegalDocumentType) -> String? {
        switch documentType {
        case .terms:
            guard user.acceptedTerms else { return nil }
            return user.acceptedTermsVersion?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        case .privacy:
            guard user.acceptedPrivacyPolicy else { return nil }
            return user.acceptedPrivacyPolicyVersion?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        case .imprint:
            return nil
        }
    }

    private static func bundledFallbackVersion(documentType: LegalDocumentType) -> String {
        switch documentType {
        case .terms: TermsVersionConstants.currentTermsVersion
        case .privacy: TermsVersionConstants.currentPrivacyPolicyVersion
        case .imprint: "1.0"
        }
    }
}

private extension String {
    var nonEmpty: String? {
        self.isEmpty ? nil : self
    }
}
