import Foundation

/// Data provider for Terms of Service content
/// Provides localized Terms sections for English and German
struct TermsOfServiceDataProvider {

    // MARK: - Terms Section Model

    struct TermsSection: Identifiable, Hashable {
        let id: String
        let title: String
        let content: String
        let icon: String
    }

    // MARK: - Language Support

    enum Language: String, CaseIterable {
        case english = "en"
        case german = "de"

        var displayName: String {
            switch self {
            case .english: return "English"
            case .german: return "Deutsch"
            }
        }

        var flag: String {
            switch self {
            case .english: return "🇬🇧"
            case .german: return "🇩🇪"
            }
        }

        /// Returns the flag for the opposite language (for toggle button)
        var oppositeFlag: String {
            switch self {
            case .english: return "🇩🇪"
            case .german: return "🇬🇧"
            }
        }
    }

    // MARK: - Public API

    static func sections(for language: Language, commissionRate: Double) -> [TermsSection] {
        language == .english
            ? TermsOfServiceEnglishContent.sections(commissionRate: commissionRate)
            : TermsOfServiceGermanContent.sections(commissionRate: commissionRate)
    }
}
