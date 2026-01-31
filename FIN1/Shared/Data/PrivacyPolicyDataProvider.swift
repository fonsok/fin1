import Foundation

/// Data provider for Privacy Policy content
/// Provides jurisdiction-specific Privacy Policy sections (American or German)
struct PrivacyPolicyDataProvider {

    // MARK: - Privacy Policy Section Model

    struct PrivacySection: Identifiable, Hashable {
        let id: String
        let title: String
        let content: String
        let icon: String
    }

    // MARK: - Jurisdiction Support

    enum Jurisdiction: String, CaseIterable {
        case american = "us"
        case german = "de"

        var displayName: String {
            switch self {
            case .american: return "American"
            case .german: return "German"
            }
        }

        var flag: String {
            switch self {
            case .american: return "🇺🇸"
            case .german: return "🇩🇪"
            }
        }

        var language: String {
            switch self {
            case .american: return "English"
            case .german: return "Deutsch"
            }
        }
    }

    // MARK: - Public API

    /// Get Privacy Policy sections for the specified jurisdiction
    /// - Parameter jurisdiction: .american for US law (English), .german for German/EU law (German)
    /// - Returns: Array of Privacy Policy sections
    static func sections(for jurisdiction: Jurisdiction) -> [PrivacySection] {
        switch jurisdiction {
        case .american:
            return PrivacyPolicyAmericanContent.sections
        case .german:
            return PrivacyPolicyGermanContent.sections
        }
    }

    /// Determine jurisdiction from user data
    /// - Parameters:
    ///   - country: User's country
    ///   - nationality: User's nationality
    ///   - isNotUSCitizen: Whether user is NOT a US citizen
    /// - Returns: Determined jurisdiction
    static func determineJurisdiction(
        country: String?,
        nationality: String?,
        isNotUSCitizen: Bool?
    ) -> Jurisdiction {
        // Check if user is American
        let isAmerican = !(isNotUSCitizen ?? true) ||
            country?.lowercased().contains("united states") == true ||
            country?.lowercased().contains("usa") == true ||
            country?.lowercased().contains("us") == true ||
            nationality?.lowercased().contains("american") == true ||
            nationality?.lowercased().contains("united states") == true

        return isAmerican ? .american : .german
    }
}

