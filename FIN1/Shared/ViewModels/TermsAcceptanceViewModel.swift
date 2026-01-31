import Foundation
import Combine

// MARK: - Terms Acceptance ViewModel

/// ViewModel for managing Terms of Service and Privacy Policy acceptance flow
/// Handles forced acceptance modal and user interactions
@MainActor
final class TermsAcceptanceViewModel: ObservableObject {

    // MARK: - Dependencies

    private let termsAcceptanceService: any TermsAcceptanceServiceProtocol
    private let userService: any UserServiceProtocol
    private let parseAPIClient: (any ParseAPIClientProtocol)?
    private let termsContentService: (any TermsContentServiceProtocol)?

    // MARK: - Published Properties

    @Published var needsTermsAcceptance: Bool = false
    @Published var needsPrivacyPolicyAcceptance: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var currentTermsVersionForDisplay: String = TermsVersionConstants.currentTermsVersion
    @Published private(set) var currentPrivacyVersionForDisplay: String = TermsVersionConstants.currentPrivacyPolicyVersion
    @Published private(set) var currentTermsHash: String?
    @Published private(set) var currentPrivacyHash: String?

    // MARK: - Initialization

    init(
        termsAcceptanceService: any TermsAcceptanceServiceProtocol,
        userService: any UserServiceProtocol,
        parseAPIClient: (any ParseAPIClientProtocol)? = nil,
        termsContentService: (any TermsContentServiceProtocol)? = nil
    ) {
        self.termsAcceptanceService = termsAcceptanceService
        self.userService = userService
        self.parseAPIClient = parseAPIClient
        self.termsContentService = termsContentService
        Task { [weak self] in
            await self?.refreshCurrentDocuments()
            self?.checkAcceptanceStatus()
        }
    }

    // MARK: - Acceptance Status

    func checkAcceptanceStatus() {
        guard let user = userService.currentUser else {
            needsTermsAcceptance = false
            needsPrivacyPolicyAcceptance = false
            return
        }

        // Prefer server-driven versions when available; fallback to bundled constants.
        let currentTermsVersion = currentTermsVersionForDisplay
        let currentPrivacyVersion = currentPrivacyVersionForDisplay

        needsTermsAcceptance = (user.acceptedTermsVersion ?? "") != currentTermsVersion
        needsPrivacyPolicyAcceptance = (user.acceptedPrivacyPolicyVersion ?? "") != currentPrivacyVersion
    }

    // MARK: - Acceptance Actions

    func acceptTerms() async {
        guard let user = userService.currentUser else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let versionToAccept = currentTermsVersionForDisplay
            let updatedUser = termsAcceptanceService.recordTermsAcceptance(
                user: user,
                version: versionToAccept
            )

            try await userService.updateProfile(updatedUser)
            await recordConsentInBackendIfPossible(
                consentType: "terms_of_service",
                version: versionToAccept,
                documentHash: currentTermsHash
            )

            needsTermsAcceptance = false
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func acceptPrivacyPolicy() async {
        guard let user = userService.currentUser else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let versionToAccept = currentPrivacyVersionForDisplay
            let updatedUser = termsAcceptanceService.recordPrivacyPolicyAcceptance(
                user: user,
                version: versionToAccept
            )

            try await userService.updateProfile(updatedUser)
            await recordConsentInBackendIfPossible(
                consentType: "privacy_policy",
                version: versionToAccept,
                documentHash: currentPrivacyHash
            )

            needsPrivacyPolicyAcceptance = false
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Computed Properties

    var canProceed: Bool {
        !needsTermsAcceptance && !needsPrivacyPolicyAcceptance
    }

    // MARK: - Backend Consent Recording (Audit)

    private struct ConsentResult: Codable {
        let objectId: String?
        let acceptedAt: String?
    }

    private func recordConsentInBackendIfPossible(
        consentType: String,
        version: String,
        documentHash: String?
    ) async {
        guard let parseAPIClient else { return }

        var parameters: [String: Any] = [
            "consentType": consentType,
            "version": version,
            "platform": AppBuildInfo.platform,
            "appVersion": AppBuildInfo.appVersion,
            "buildNumber": AppBuildInfo.buildNumber,
            "deviceInstallId": DeviceInstallIdProvider.getOrCreate()
        ]
        if let documentHash, !documentHash.isEmpty {
            parameters["documentHash"] = documentHash
        }

        let _: ConsentResult? = try? await parseAPIClient.callFunction(
            "recordLegalConsent",
            parameters: parameters
        )
    }

    private func refreshCurrentDocuments() async {
        guard let termsContentService else { return }
        guard userService.currentUser != nil else { return }

        let termsLanguage: TermsOfServiceDataProvider.Language = {
            Locale.current.language.languageCode?.identifier == "de" ? .german : .english
        }()

        let privacyLanguage: TermsOfServiceDataProvider.Language = {
            guard let user = userService.currentUser else { return .german }
            let jurisdiction = PrivacyPolicyDataProvider.determineJurisdiction(
                country: user.country,
                nationality: user.nationality,
                isNotUSCitizen: user.isNotUSCitizen
            )
            return (jurisdiction == .american) ? .english : .german
        }()

        func resolve(language: TermsOfServiceDataProvider.Language, doc: LegalDocumentType) async -> TermsContent? {
            if let cached = termsContentService.getCachedTerms(language: language, documentType: doc) {
                return cached
            }
            return try? await termsContentService.fetchCurrentTerms(language: language, documentType: doc)
        }

        if let terms = await resolve(language: termsLanguage, doc: .terms) {
            currentTermsVersionForDisplay = terms.version
            currentTermsHash = terms.documentHash
        }

        if let privacy = await resolve(language: privacyLanguage, doc: .privacy) {
            currentPrivacyVersionForDisplay = privacy.version
            currentPrivacyHash = privacy.documentHash
        }
    }
}







