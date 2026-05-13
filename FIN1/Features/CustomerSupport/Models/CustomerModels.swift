import Foundation

// MARK: - Customer Search Result

struct CustomerSearchResult: Identifiable, Codable {
    let id: String
    let customerNumber: String
    let fullName: String
    let email: String
    let role: String
    let isKYCCompleted: Bool
    let accountStatus: AccountStatus
    let lastActivity: Date?

    enum AccountStatus: String, Codable {
        case active
        case locked
        case pendingVerification
        case suspended

        var displayName: String {
            switch self {
            case .active: return "Aktiv"
            case .locked: return "Gesperrt"
            case .pendingVerification: return "Ausstehende Verifizierung"
            case .suspended: return "Suspendiert"
            }
        }

        var color: String {
            switch self {
            case .active: return "green"
            case .locked: return "red"
            case .pendingVerification: return "orange"
            case .suspended: return "gray"
            }
        }
    }
}

// MARK: - Customer Profile (Read-Only View)

struct CustomerProfile: Identifiable, Codable {
    let id: String
    let customerNumber: String
    let salutation: String
    let academicTitle: String?
    let firstName: String
    let lastName: String
    let email: String
    let phoneNumber: String
    let role: String
    let accountType: String
    let createdAt: Date

    // Address (may be partially redacted based on permissions)
    let streetAndNumber: String?
    let postalCode: String?
    let city: String?
    let state: String?
    let country: String?

    // Preferred language for communication
    let language: String?

    // Verification status
    let isEmailVerified: Bool
    let isKYCCompleted: Bool
    let identificationConfirmed: Bool
    let addressConfirmed: Bool

    // Account status
    let accountStatus: CustomerSearchResult.AccountStatus
    let lastLoginDate: Date?

    var fullName: String {
        if let title = academicTitle, !title.isEmpty {
            return "\(title) \(self.firstName) \(self.lastName)"
        }
        return "\(self.firstName) \(self.lastName)"
    }

    var formattedAddress: String? {
        guard let street = streetAndNumber,
              let postal = postalCode,
              let city = city,
              let country = country else {
            return nil
        }
        return "\(street), \(postal) \(city), \(country)"
    }
}

// MARK: - Customer Investment Summary

struct CustomerInvestmentSummary: Identifiable, Codable {
    let id: String
    let investmentNumber: String
    let traderName: String
    let amount: Double
    let currentValue: Double
    let returnPercentage: Double?
    let status: String
    let createdAt: Date
    let completedAt: Date?
}

// MARK: - Customer Trade Summary

struct CustomerTradeSummary: Identifiable, Codable {
    let id: String
    let tradeNumber: String
    let symbol: String
    let direction: String // Buy/Sell
    let quantity: Int
    let entryPrice: Double
    let currentPrice: Double?
    let profitLoss: Double?
    let status: String
    let createdAt: Date
}

// MARK: - Customer Document Summary

struct CustomerDocumentSummary: Identifiable, Codable {
    let id: String
    let name: String
    let type: String
    let uploadedAt: Date
    let isVerified: Bool
    let category: String
}

// MARK: - Customer KYC Status

struct CustomerKYCStatus: Codable {
    let customerNumber: String
    let overallStatus: KYCOverallStatus
    let emailVerified: Bool
    let identityVerified: Bool
    let addressVerified: Bool
    let riskClassification: Int?
    let lastUpdated: Date
    let pendingDocuments: [String]
    let notes: String?

    enum KYCOverallStatus: String, Codable {
        case complete
        case inProgress
        case pendingReview
        case rejected
        case expired

        var displayName: String {
            switch self {
            case .complete: return "Vollständig"
            case .inProgress: return "In Bearbeitung"
            case .pendingReview: return "Prüfung ausstehend"
            case .rejected: return "Abgelehnt"
            case .expired: return "Abgelaufen"
            }
        }
    }
}

