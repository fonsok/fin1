import Foundation

// MARK: - Template Category
/// Categories for CSR response templates
enum TemplateCategory: String, CaseIterable, Codable {
    case greeting = "Begrüßung"
    case accountIssues = "Konto-Probleme"
    case kycOnboarding = "KYC/Onboarding"
    case transactions = "Transaktionen"
    case security = "Sicherheit"
    case fraud = "Betrug"
    case compliance = "Compliance"
    case gdpr = "DSGVO"
    case technical = "Technisch"
    case escalation = "Eskalation"
    case closing = "Abschluss"
    case general = "Allgemein"

    var icon: String {
        switch self {
        case .greeting: return "hand.wave.fill"
        case .accountIssues: return "person.crop.circle.badge.exclamationmark"
        case .kycOnboarding: return "checkmark.shield.fill"
        case .transactions: return "arrow.left.arrow.right"
        case .security: return "lock.shield.fill"
        case .fraud: return "exclamationmark.triangle.fill"
        case .compliance: return "doc.text.magnifyingglass"
        case .gdpr: return "hand.raised.fill"
        case .technical: return "wrench.and.screwdriver.fill"
        case .escalation: return "arrow.up.circle.fill"
        case .closing: return "checkmark.circle.fill"
        case .general: return "doc.text"
        }
    }
}
