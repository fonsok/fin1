import Foundation

// MARK: - Terms Acceptance Service Implementation

/// Service for managing Terms of Service and Privacy Policy acceptance
/// Handles version checking and acceptance recording
final class TermsAcceptanceService: TermsAcceptanceServiceProtocol {

    private enum ConsentType {
        static let terms = "terms_of_service"
        static let privacy = "privacy_policy"
    }

    // MARK: - Initialization

    init() {
        // Service is stateless, no initialization needed
    }

    // MARK: - Acceptance Checks

    func needsToAcceptTerms(user: User, currentServerVersion: String) -> Bool {
        let currentVersion = currentServerVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentVersion.isEmpty else { return true }
        guard user.acceptedTerms else { return true }
        guard let acceptedVersion = user.acceptedTermsVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !acceptedVersion.isEmpty else {
            return true
        }
        guard acceptedVersion == currentVersion else { return true }
        return !DeviceLegalConsentStore.hasAcknowledged(consentType: ConsentType.terms, version: currentVersion)
    }

    func needsToAcceptPrivacyPolicy(user: User, currentServerVersion: String) -> Bool {
        let currentVersion = currentServerVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentVersion.isEmpty else { return true }
        guard user.acceptedPrivacyPolicy else { return true }
        guard let acceptedVersion = user.acceptedPrivacyPolicyVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !acceptedVersion.isEmpty else {
            return true
        }
        guard acceptedVersion == currentVersion else { return true }
        return !DeviceLegalConsentStore.hasAcknowledged(consentType: ConsentType.privacy, version: currentVersion)
    }

    func needsToAcceptNewTerms(user: User) -> Bool {
        self.needsToAcceptTerms(user: user, currentServerVersion: TermsVersionConstants.currentTermsVersion)
    }

    func needsToAcceptNewPrivacyPolicy(user: User) -> Bool {
        self.needsToAcceptPrivacyPolicy(user: user, currentServerVersion: TermsVersionConstants.currentPrivacyPolicyVersion)
    }

    func needsToAcceptAnyNewDocument(user: User) -> Bool {
        self.needsToAcceptNewTerms(user: user) || self.needsToAcceptNewPrivacyPolicy(user: user)
    }

    // MARK: - Acceptance Recording

    func recordTermsAcceptance(user: User, version: String) -> User {
        var updatedUser = user
        updatedUser.acceptedTerms = true
        updatedUser.acceptedTermsVersion = version
        updatedUser.acceptedTermsDate = Date()
        updatedUser.updatedAt = Date()
        DeviceLegalConsentStore.markAcknowledged(consentType: ConsentType.terms, version: version)
        return updatedUser
    }

    func recordPrivacyPolicyAcceptance(user: User, version: String) -> User {
        var updatedUser = user
        updatedUser.acceptedPrivacyPolicy = true
        updatedUser.acceptedPrivacyPolicyVersion = version
        updatedUser.acceptedPrivacyPolicyDate = Date()
        updatedUser.updatedAt = Date()
        DeviceLegalConsentStore.markAcknowledged(consentType: ConsentType.privacy, version: version)
        return updatedUser
    }
}
