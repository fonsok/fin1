import Foundation

// MARK: - Terms Acceptance Service Implementation

/// Service for managing Terms of Service and Privacy Policy acceptance
/// Handles version checking and acceptance recording
final class TermsAcceptanceService: TermsAcceptanceServiceProtocol {

    // MARK: - Initialization

    init() {
        // Service is stateless, no initialization needed
    }

    // MARK: - Acceptance Checks

    func needsToAcceptNewTerms(user: User) -> Bool {
        // If user has never accepted terms, they need to accept
        guard let acceptedVersion = user.acceptedTermsVersion else {
            return true
        }

        // If accepted version doesn't match current version, need to accept
        return acceptedVersion != TermsVersionConstants.currentTermsVersion
    }

    func needsToAcceptNewPrivacyPolicy(user: User) -> Bool {
        // If user has never accepted privacy policy, they need to accept
        guard let acceptedVersion = user.acceptedPrivacyPolicyVersion else {
            return true
        }

        // If accepted version doesn't match current version, need to accept
        return acceptedVersion != TermsVersionConstants.currentPrivacyPolicyVersion
    }

    func needsToAcceptAnyNewDocument(user: User) -> Bool {
        needsToAcceptNewTerms(user: user) || needsToAcceptNewPrivacyPolicy(user: user)
    }

    // MARK: - Acceptance Recording

    func recordTermsAcceptance(user: User, version: String) -> User {
        var updatedUser = user
        updatedUser.acceptedTerms = true
        updatedUser.acceptedTermsVersion = version
        updatedUser.acceptedTermsDate = Date()
        updatedUser.updatedAt = Date()
        return updatedUser
    }

    func recordPrivacyPolicyAcceptance(user: User, version: String) -> User {
        var updatedUser = user
        updatedUser.acceptedPrivacyPolicy = true
        updatedUser.acceptedPrivacyPolicyVersion = version
        updatedUser.acceptedPrivacyPolicyDate = Date()
        updatedUser.updatedAt = Date()
        return updatedUser
    }
}







