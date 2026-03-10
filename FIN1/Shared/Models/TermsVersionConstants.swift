import Foundation

// MARK: - Terms Version Constants

/// Centralized constants for Terms of Service version management
struct TermsVersionConstants {

    // MARK: - Current Version

    /// Current Terms of Service version
    /// Update this when Terms content changes materially
    static let currentTermsVersion: String = "1.0"

    /// Current Privacy Policy version
    /// Update this when Privacy Policy content changes materially
    static let currentPrivacyPolicyVersion: String = "1.0"

    // MARK: - Version Metadata

    /// Effective date for current Terms version
    static let currentTermsEffectiveDate: Date = {
        // Set to the date when current version became effective
        // Format: YYYY-MM-DD
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: "2024-01-01") ?? Date()
    }()

    /// Effective date for current Privacy Policy version
    static let currentPrivacyPolicyEffectiveDate: Date = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: "2024-01-01") ?? Date()
    }()

    // MARK: - Questionnaire Version

    /// Version of the MiFID-II risk/experience questionnaire.
    /// Increment when questions, answer options, or scoring weights change.
    static let currentQuestionnaireVersion: String = "1.0"

    // MARK: - Acceptance Requirements

    /// Whether material changes require explicit acceptance (not just continued use)
    /// For financial services in Germany, material changes typically require explicit consent
    static let requiresExplicitAcceptance: Bool = true

    /// Minimum notice period in days before new terms become effective
    /// As per Terms: "Material changes will be communicated with at least 30 days' notice"
    static let minimumNoticePeriodDays: Int = 30
}







