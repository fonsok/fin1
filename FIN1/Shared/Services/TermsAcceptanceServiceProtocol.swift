import Foundation

// MARK: - Terms Acceptance Service Protocol

/// Defines the contract for Terms of Service acceptance management
protocol TermsAcceptanceServiceProtocol {

    // MARK: - Acceptance Checks

    /// Checks if user needs to accept new Terms of Service version
    /// - Parameter user: The user to check
    /// - Returns: True if user needs to accept new terms
    func needsToAcceptNewTerms(user: User) -> Bool

    /// Checks if user needs to accept new Privacy Policy version
    /// - Parameter user: The user to check
    /// - Returns: True if user needs to accept new privacy policy
    func needsToAcceptNewPrivacyPolicy(user: User) -> Bool

    /// Checks if user needs to accept any new legal documents
    /// - Parameter user: The user to check
    /// - Returns: True if user needs to accept terms or privacy policy
    func needsToAcceptAnyNewDocument(user: User) -> Bool

    // MARK: - Acceptance Recording

    /// Records Terms of Service acceptance for a user
    /// - Parameters:
    ///   - user: The user accepting terms
    ///   - version: The version being accepted
    /// - Returns: Updated user with acceptance recorded
    func recordTermsAcceptance(user: User, version: String) -> User

    /// Records Privacy Policy acceptance for a user
    /// - Parameters:
    ///   - user: The user accepting privacy policy
    ///   - version: The version being accepted
    /// - Returns: Updated user with acceptance recorded
    func recordPrivacyPolicyAcceptance(user: User, version: String) -> User
}







