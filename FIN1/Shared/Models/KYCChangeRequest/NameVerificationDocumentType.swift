import Foundation

// MARK: - Name Verification Document Types

/// Types of documents accepted for name change verification per GwG requirements
enum NameVerificationDocumentType: String, CaseIterable, Codable, Hashable {
    case marriageCertificate    // Heiratsurkunde
    case divorceCertificate     // Scheidungsurkunde
    case adoptionCertificate    // Adoptionsurkunde
    case courtDecree            // Gerichtsbeschluss zur Namensänderung
    case birthCertificate       // Geburtsurkunde (for corrections)
    case newIdCard              // Neuer Personalausweis mit geändertem Namen
    case newPassport            // Neuer Reisepass mit geändertem Namen

    var displayName: String {
        switch self {
        case .marriageCertificate: return "Marriage Certificate"
        case .divorceCertificate: return "Divorce Certificate"
        case .adoptionCertificate: return "Adoption Certificate"
        case .courtDecree: return "Court Decree"
        case .birthCertificate: return "Birth Certificate"
        case .newIdCard: return "New ID Card"
        case .newPassport: return "New Passport"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .marriageCertificate: return "Heiratsurkunde"
        case .divorceCertificate: return "Scheidungsurkunde"
        case .adoptionCertificate: return "Adoptionsurkunde"
        case .courtDecree: return "Gerichtsbeschluss"
        case .birthCertificate: return "Geburtsurkunde"
        case .newIdCard: return "Neuer Personalausweis"
        case .newPassport: return "Neuer Reisepass"
        }
    }

    var description: String {
        switch self {
        case .marriageCertificate:
            return "Official marriage certificate issued by the registry office (Standesamt)"
        case .divorceCertificate:
            return "Official divorce decree or certificate"
        case .adoptionCertificate:
            return "Official adoption certificate issued by competent authority"
        case .courtDecree:
            return "Court order approving the name change"
        case .birthCertificate:
            return "Birth certificate showing correct name spelling"
        case .newIdCard:
            return "New German ID card (Personalausweis) showing the updated name"
        case .newPassport:
            return "New passport showing the updated name"
        }
    }

    var icon: String {
        switch self {
        case .marriageCertificate: return "heart.text.square.fill"
        case .divorceCertificate: return "doc.text.fill"
        case .adoptionCertificate: return "doc.badge.plus"
        case .courtDecree: return "building.columns.fill"
        case .birthCertificate: return "doc.text.fill"
        case .newIdCard: return "person.text.rectangle.fill"
        case .newPassport: return "book.closed.fill"
        }
    }

    /// Whether this is a primary document (certificate/decree) or identity document
    var isPrimaryDocument: Bool {
        switch self {
        case .marriageCertificate, .divorceCertificate, .adoptionCertificate,
             .courtDecree, .birthCertificate:
            return true
        case .newIdCard, .newPassport:
            return false
        }
    }
}





