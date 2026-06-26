import Foundation

/// Server-driven post-onboarding consent drift (`getUserMe.requiredReConsents`).
struct RequiredReConsent: Codable, Sendable, Equatable, Identifiable {
    let consentType: String
    let documentType: String
    let activeVersion: String
    let userVersion: String
    let blocking: Bool
    let requiresScrollToAccept: Bool

    var id: String { self.consentType }

    var isRoleAgreement: Bool {
        self.consentType == "trader_agreement" || self.consentType == "investor_agreement"
    }

    var isTermsOfService: Bool { self.consentType == "terms_of_service" }

    var isPrivacyPolicy: Bool { self.consentType == "privacy_policy" }

    var displayTitle: String {
        switch self.consentType {
        case "terms_of_service":
            return String(localized: "Allgemeine Geschäftsbedingungen")
        case "privacy_policy":
            return String(localized: "Datenschutzerklärung")
        case "trader_agreement":
            return String(localized: "Signalgeber-Vereinbarung")
        case "investor_agreement":
            return String(localized: "Investor-Vereinbarung")
        default:
            return String(localized: "Rechtliches Dokument")
        }
    }
}
