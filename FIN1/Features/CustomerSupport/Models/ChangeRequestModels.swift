import Foundation

// MARK: - Change Request

struct ChangeRequest: Identifiable, Codable {
    let id: String
    let requestType: ChangeRequestType
    let customerId: String
    let requestedBy: String
    let status: ChangeRequestStatus
    let previousValue: String
    let newValue: String
    let reason: String
    let createdAt: Date
    let reviewedBy: String?
    let reviewedAt: Date?
    let reviewNotes: String?

    enum ChangeRequestType: String, Codable {
        case address
        case name
        case email
        case phone

        var displayName: String {
            switch self {
            case .address: return "Adressänderung"
            case .name: return "Namensänderung"
            case .email: return "E-Mail-Änderung"
            case .phone: return "Telefonnummer-Änderung"
            }
        }
    }

    enum ChangeRequestStatus: String, Codable {
        case pending
        case approved
        case rejected
        case cancelled

        var displayName: String {
            switch self {
            case .pending: return "Ausstehend"
            case .approved: return "Genehmigt"
            case .rejected: return "Abgelehnt"
            case .cancelled: return "Storniert"
            }
        }
    }
}

// MARK: - Customer Support Address Change Request DTO

struct CSAddressChangeInput: Codable {
    let streetAndNumber: String
    let postalCode: String
    let city: String
    let state: String
    let country: String
    let reason: String
}

// MARK: - Customer Support Name Change Request DTO

struct CSNameChangeInput: Codable {
    let firstName: String?
    let lastName: String?
    let academicTitle: String?
    let reason: String
    let supportingDocumentId: String?
}

