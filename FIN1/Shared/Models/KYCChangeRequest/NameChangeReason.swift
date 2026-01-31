import Foundation

// MARK: - Name Change Reason

/// Reasons for name change - determines required documentation
/// Marriage and divorce are considered highly relevant life events affecting risk profile
enum NameChangeReason: String, CaseIterable, Codable, Hashable {
    case marriage           // Taking spouse's name or double-barreled name
    case divorce            // Reverting to maiden name
    case adoption           // Name change due to adoption
    case courtOrder         // Legal name change by court order
    case genderTransition   // Name change related to gender transition
    case correction         // Correction of spelling/typographical error
    case other              // Other legally recognized reasons

    var displayName: String {
        switch self {
        case .marriage: return "Marriage"
        case .divorce: return "Divorce"
        case .adoption: return "Adoption"
        case .courtOrder: return "Court Order"
        case .genderTransition: return "Gender Transition"
        case .correction: return "Spelling Correction"
        case .other: return "Other Legal Reason"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .marriage: return "Eheschließung"
        case .divorce: return "Scheidung"
        case .adoption: return "Adoption"
        case .courtOrder: return "Gerichtsbeschluss"
        case .genderTransition: return "Geschlechtsangleichung"
        case .correction: return "Schreibfehlerkorrektur"
        case .other: return "Sonstige rechtliche Gründe"
        }
    }

    var description: String {
        switch self {
        case .marriage:
            return "Name change due to marriage (taking partner's name or adopting a double-barreled name)"
        case .divorce:
            return "Reverting to previous name following divorce"
        case .adoption:
            return "Name change due to legal adoption"
        case .courtOrder:
            return "Name change ordered by court (e.g., name change application)"
        case .genderTransition:
            return "Name change related to gender transition"
        case .correction:
            return "Correction of spelling or typographical errors in registered name"
        case .other:
            return "Other legally recognized reason for name change"
        }
    }

    /// Required documents for this type of name change
    var requiredDocumentTypes: [NameVerificationDocumentType] {
        switch self {
        case .marriage:
            return [.marriageCertificate, .newIdCard, .newPassport]
        case .divorce:
            return [.divorceCertificate, .newIdCard, .newPassport]
        case .adoption:
            return [.adoptionCertificate, .newIdCard, .newPassport]
        case .courtOrder:
            return [.courtDecree, .newIdCard, .newPassport]
        case .genderTransition:
            return [.courtDecree, .newIdCard, .newPassport]
        case .correction:
            return [.birthCertificate, .newIdCard, .newPassport]
        case .other:
            return [.courtDecree, .newIdCard, .newPassport]
        }
    }

    var icon: String {
        switch self {
        case .marriage: return "heart.fill"
        case .divorce: return "heart.slash.fill"
        case .adoption: return "figure.2.and.child.holdinghands"
        case .courtOrder: return "building.columns.fill"
        case .genderTransition: return "person.fill.questionmark"
        case .correction: return "pencil.circle.fill"
        case .other: return "doc.text.fill"
        }
    }

    /// Whether this is a significant life event requiring heightened scrutiny per GwG
    var isSignificantLifeEvent: Bool {
        switch self {
        case .marriage, .divorce, .adoption:
            return true
        default:
            return false
        }
    }
}





