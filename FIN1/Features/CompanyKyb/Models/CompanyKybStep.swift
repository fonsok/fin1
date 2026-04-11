import Foundation

// MARK: - Company KYB Step

enum CompanyKybStep: Int, CaseIterable, Identifiable, Sendable {
    case legalEntity = 1
    case registeredAddress = 2
    case taxCompliance = 3
    case beneficialOwners = 4
    case authorizedRepresentatives = 5
    case documents = 6
    case declarations = 7
    case submission = 8

    var id: Int { rawValue }

    var backendKey: String {
        switch self {
        case .legalEntity: return "legal_entity"
        case .registeredAddress: return "registered_address"
        case .taxCompliance: return "tax_compliance"
        case .beneficialOwners: return "beneficial_owners"
        case .authorizedRepresentatives: return "authorized_representatives"
        case .documents: return "documents"
        case .declarations: return "declarations"
        case .submission: return "submission"
        }
    }

    var title: String {
        switch self {
        case .legalEntity: return "Unternehmen"
        case .registeredAddress: return "Sitz & Anschrift"
        case .taxCompliance: return "Steuern & Identifikatoren"
        case .beneficialOwners: return "Wirtschaftlich Berechtigte"
        case .authorizedRepresentatives: return "Vertretung"
        case .documents: return "Nachweise"
        case .declarations: return "Erklärungen"
        case .submission: return "Einreichung"
        }
    }

    var subtitle: String {
        switch self {
        case .legalEntity: return "Firma, Rechtsform und Registerdaten"
        case .registeredAddress: return "Eingetragener Sitz der Gesellschaft"
        case .taxCompliance: return "Umsatzsteuer-ID und Steuernummern"
        case .beneficialOwners: return "Wirtschaftlich Berechtigte (UBOs)"
        case .authorizedRepresentatives: return "Vertretungsberechtigte Personen"
        case .documents: return "Erforderliche Unternehmensdokumente"
        case .declarations: return "PEP, Sanktionen und Richtigkeit"
        case .submission: return "Zusammenfassung prüfen und einreichen"
        }
    }

    var icon: String {
        switch self {
        case .legalEntity: return "building.2"
        case .registeredAddress: return "mappin.and.ellipse"
        case .taxCompliance: return "doc.text"
        case .beneficialOwners: return "person.3"
        case .authorizedRepresentatives: return "person.badge.key"
        case .documents: return "folder"
        case .declarations: return "checkmark.shield"
        case .submission: return "paperplane"
        }
    }

    static func fromBackendKey(_ key: String) -> CompanyKybStep? {
        allCases.first { $0.backendKey == key }
    }

    var next: CompanyKybStep? {
        CompanyKybStep(rawValue: rawValue + 1)
    }

    var previous: CompanyKybStep? {
        CompanyKybStep(rawValue: rawValue - 1)
    }

    static var totalSteps: Int { allCases.count }
}
