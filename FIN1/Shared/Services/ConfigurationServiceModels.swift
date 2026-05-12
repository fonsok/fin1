import Foundation

// MARK: - Parse config API responses
struct GetConfigResponse: Decodable {
    let financial: FinancialSection?
    let limits: LimitsSection?
    let display: DisplaySection?

    struct LimitsSection: Decodable {
        let minInvestment: Double?
        let maxInvestment: Double?
    }

    struct FinancialSection: Decodable {
        let initialAccountBalance: Double?
        let traderCommissionRate: Double?
        let platformServiceChargeRate: Double?
        let appServiceChargeRate: Double?
        let platformServiceChargeRateCompanies: Double?
        let appServiceChargeRateCompanies: Double?
        let minimumCashReserve: Double?
    }

    struct DisplaySection: Decodable {
        let showCommissionBreakdownInCreditNote: Bool?
        let showDocumentReferenceLinksInAccountStatement: Bool?
        let maximumRiskExposurePercent: Double?
        let walletFeatureEnabled: Bool?
        let serviceChargeInvoiceFromBackend: Bool?
        let serviceChargeLegacyClientFallbackEnabled: Bool?
        let serviceChargeLegacyDisableAllowedFrom: String?
    }
}

struct UpdateConfigResponse: Decodable {
    let display: GetConfigResponse.DisplaySection?
}

// MARK: - 4-Eyes configuration models
struct ConfigurationChangeRequestResponse: Decodable {
    let success: Bool
    let requiresApproval: Bool
    let fourEyesRequestId: String?
    let message: String
}

struct ConfigurationChangeApprovalResponse: Decodable {
    let success: Bool
    let message: String
    let appliedValue: Double?
}

struct PendingConfigurationChange: Decodable, Identifiable {
    let id: String
    let parameterName: String
    let oldValue: Double
    let newValue: Double
    let reason: String
    let requesterId: String
    let requesterEmail: String?
    let requesterRole: String
    let createdAt: Date
    let expiresAt: Date
}

struct PendingConfigurationChangesResponse: Decodable {
    let requests: [PendingConfigurationChange]
    let total: Int
}

enum CriticalConfigurationParameter: String, CaseIterable {
    case traderCommissionRate
    case appServiceChargeRate
    case appServiceChargeRateCompanies
    case initialAccountBalance
    case orderFeeRate
    case orderFeeMin
    case orderFeeMax

    var displayName: String {
        switch self {
        case .traderCommissionRate: return "Trader Commission Rate"
        case .appServiceChargeRate: return "App Service Charge Rate"
        case .appServiceChargeRateCompanies: return "App Service Charge Rate Companies"
        case .initialAccountBalance: return "Initial Account Balance"
        case .orderFeeRate: return "Order Fee Rate"
        case .orderFeeMin: return "Order Fee Minimum"
        case .orderFeeMax: return "Order Fee Maximum"
        }
    }

    static func isCritical(_ parameterName: String) -> Bool {
        CriticalConfigurationParameter(rawValue: parameterName) != nil
    }
}
