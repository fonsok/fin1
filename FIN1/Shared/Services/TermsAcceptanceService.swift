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
        self.needsDeviceAcknowledgement(
            user: user,
            consentType: ConsentType.terms,
            isAcceptedOnAccount: user.acceptedTerms,
            acceptedVersionOnAccount: user.acceptedTermsVersion,
            currentServerVersion: currentServerVersion
        )
    }

    func needsToAcceptPrivacyPolicy(user: User, currentServerVersion: String) -> Bool {
        self.needsDeviceAcknowledgement(
            user: user,
            consentType: ConsentType.privacy,
            isAcceptedOnAccount: user.acceptedPrivacyPolicy,
            acceptedVersionOnAccount: user.acceptedPrivacyPolicyVersion,
            currentServerVersion: currentServerVersion
        )
    }

    /// Install gate: device ack for the active version ends the prompt. Account flags/version decide fresh install vs bump.
    private func needsDeviceAcknowledgement(
        user: User,
        consentType: String,
        isAcceptedOnAccount: Bool,
        acceptedVersionOnAccount: String?,
        currentServerVersion: String
    ) -> Bool {
        let currentVersion = currentServerVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentVersion.isEmpty else { return true }

        if DeviceLegalConsentStore.hasAcknowledged(
            user: user,
            consentType: consentType,
            version: currentVersion
        ) {
            return false
        }

        guard isAcceptedOnAccount else { return true }
        guard let acceptedVersion = acceptedVersionOnAccount?.trimmingCharacters(in: .whitespacesAndNewlines),
              !acceptedVersion.isEmpty else {
            return true
        }
        if acceptedVersion != currentVersion {
            return true
        }

        // Account matches active version, but this install has not confirmed yet.
        return true
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
        DeviceLegalConsentStore.markAcknowledged(user: user, consentType: ConsentType.terms, version: version)
        return updatedUser
    }

    func recordPrivacyPolicyAcceptance(user: User, version: String) -> User {
        var updatedUser = user
        updatedUser.acceptedPrivacyPolicy = true
        updatedUser.acceptedPrivacyPolicyVersion = version
        updatedUser.acceptedPrivacyPolicyDate = Date()
        updatedUser.updatedAt = Date()
        DeviceLegalConsentStore.markAcknowledged(user: user, consentType: ConsentType.privacy, version: version)
        return updatedUser
    }
}
