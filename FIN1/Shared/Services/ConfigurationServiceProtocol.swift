import Foundation
import Combine

// MARK: - Pool Balance Distribution Strategy

/// Strategy for handling small remaining pool balances after purchases
enum PoolBalanceDistributionStrategy: String, Codable, CaseIterable {
    case immediateDistribution = "immediate"
    case accumulateUntilThreshold = "accumulate"

    var displayName: String {
        switch self {
        case .immediateDistribution:
            return "Immediate Distribution"
        case .accumulateUntilThreshold:
            return "Accumulate Until Threshold"
        }
    }

    var description: String {
        switch self {
        case .immediateDistribution:
            return "Distribute remaining balance immediately if below threshold"
        case .accumulateUntilThreshold:
            return "Keep small remainders until threshold is reached, then distribute"
        }
    }
}

// MARK: - Configuration Service Protocol
/// Defines the contract for application configuration management
protocol ConfigurationServiceProtocol: ObservableObject {
    /// Publisher that fires when any configuration value changes.
    /// Use this instead of `objectWillChange` when holding `any ConfigurationServiceProtocol`.
    var configurationChanged: AnyPublisher<Void, Never> { get }

    var minimumCashReserve: Double { get }
    var initialAccountBalance: Double { get }
    var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy { get }
    var poolBalanceDistributionThreshold: Double { get }
    var traderCommissionRate: Double { get }
    var traderCommissionPercentage: String { get }
    var platformServiceChargeRate: Double { get }
    var platformServiceChargePercentage: String { get }

    /// Single source of truth for commission rate with fallback to default
    /// Use this instead of manually checking `traderCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate`
    var effectiveCommissionRate: Double { get }

    /// Single source of truth for platform service charge rate with fallback to default
    /// Use this instead of manually checking `platformServiceChargeRate ?? CalculationConstants.ServiceCharges.platformServiceChargeRate`
    var effectivePlatformServiceChargeRate: Double { get }

    var isAdminMode: Bool { get }

    /// Wenn true, wird die Commission-Breakdown-Tabelle in der Trader-Gutschrift angezeigt (Admin-Option).
    var showCommissionBreakdownInCreditNote: Bool { get }

    /// Maximum recommended risk exposure as percentage of assets (e.g. 2.0 = 2%). Shown on dashboard.
    var maximumRiskExposurePercent: Double { get }

    /// When false, Wallet (crypto) UI is hidden. Enable later when crypto trading is supported.
    var walletFeatureEnabled: Bool { get }

    // MARK: - Customer Support Configuration
    var slaMonitoringInterval: TimeInterval { get }

    // MARK: - Parse Server Configuration
    var parseServerURL: String? { get }
    var parseApplicationId: String? { get }
    var parseLiveQueryURL: String? { get }

    // MARK: - Configuration Management
    func updateMinimumCashReserve(_ value: Double) async throws
    func updateMinimumCashReserve(_ value: Double, for userId: String) async throws
    func getMinimumCashReserve(for userId: String) -> Double
    func updateInitialAccountBalance(_ value: Double) async throws
    func updatePoolBalanceDistributionStrategy(_ strategy: PoolBalanceDistributionStrategy) async throws
    func updatePoolBalanceDistributionThreshold(_ threshold: Double) async throws
    func updateTraderCommissionRate(_ rate: Double) async throws
    func updateShowCommissionBreakdownInCreditNote(_ value: Bool) async throws
    func updateMaximumRiskExposurePercent(_ value: Double) async throws
    func updatePlatformServiceChargeRate(_ rate: Double) async throws
    func updateSLAMonitoringInterval(_ interval: TimeInterval) async throws
    func resetToDefaults() async throws

    // MARK: - Validation
    func validateMinimumCashReserve(_ value: Double) -> Bool
    func validateInitialAccountBalance(_ value: Double) -> Bool
    func validatePoolBalanceDistributionThreshold(_ value: Double) -> Bool
    func validateTraderCommissionRate(_ rate: Double) -> Bool
    func validateMaximumRiskExposurePercent(_ value: Double) -> Bool
    func validatePlatformServiceChargeRate(_ rate: Double) -> Bool
    func validateSLAMonitoringInterval(_ interval: TimeInterval) -> Bool
}

// MARK: - Configuration Service Protocol Extension
extension ConfigurationServiceProtocol {
    /// Returns the trader commission percentage as a formatted string (e.g., "10%")
    var traderCommissionPercentage: String {
        "\(Int(traderCommissionRate * 100))%"
    }

    /// Single source of truth for commission rate
    /// Always use this instead of manually checking with fallback
    var effectiveCommissionRate: Double {
        traderCommissionRate
    }

    /// Returns the platform service charge percentage as a formatted string (e.g., "2%")
    var platformServiceChargePercentage: String {
        "\((platformServiceChargeRate * 100).formatted(.number.precision(.fractionLength(2))))%"
    }

    /// Single source of truth for platform service charge rate
    /// Always use this instead of manually checking with fallback
    var effectivePlatformServiceChargeRate: Double {
        platformServiceChargeRate
    }
}

// MARK: - Configuration Models
struct AppConfiguration: Codable {
    var minimumCashReserve: Double
    var initialAccountBalance: Double
    var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy
    var poolBalanceDistributionThreshold: Double
    var traderCommissionRate: Double?
    var platformServiceChargeRate: Double?
    var showCommissionBreakdownInCreditNote: Bool?
    /// Maximum recommended risk exposure as percentage of assets (e.g. 2.0 = 2%). Shown on dashboard.
    var maximumRiskExposurePercent: Double?
    /// When false, Wallet (crypto) UI is hidden. Managed via admin portal.
    var walletFeatureEnabled: Bool?
    var userMinimumCashReserves: [String: Double]
    var slaMonitoringInterval: TimeInterval
    var lastUpdated: Date
    var updatedBy: String

    static let `default` = AppConfiguration(
        minimumCashReserve: 20.0,
        initialAccountBalance: 1.0,
        poolBalanceDistributionStrategy: .immediateDistribution,
        poolBalanceDistributionThreshold: 5.0,
        traderCommissionRate: 0.10,
        platformServiceChargeRate: 0.02,
        showCommissionBreakdownInCreditNote: true,
        maximumRiskExposurePercent: 2.0,
        walletFeatureEnabled: false,
        userMinimumCashReserves: [:],
        slaMonitoringInterval: 300.0,
        lastUpdated: Date(),
        updatedBy: "system"
    )

    // Computed property to get commission rate with fallback
    var effectiveTraderCommissionRate: Double {
        traderCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate
    }

    // Computed property to get platform service charge rate with fallback
    var effectivePlatformServiceChargeRate: Double {
        platformServiceChargeRate ?? CalculationConstants.ServiceCharges.platformServiceChargeRate
    }

    /// Maximum risk exposure percent with fallback (e.g. 2.0 for 2%).
    var effectiveMaximumRiskExposurePercent: Double {
        maximumRiskExposurePercent ?? 2.0
    }

    /// Wallet feature enabled with fallback (default off until crypto is supported).
    var effectiveWalletFeatureEnabled: Bool {
        walletFeatureEnabled ?? false
    }
}

// MARK: - Configuration Errors
enum ConfigurationError: Error, LocalizedError {
    case invalidValue(String)
    case unauthorizedAccess
    case saveFailed
    case loadFailed
    case fourEyesApprovalRequired(requestId: String)
    case noBackendConnection
    case approvalRejected(reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidValue(let message):
            return "Invalid configuration value: \(message)"
        case .unauthorizedAccess:
            return "Unauthorized access to configuration settings"
        case .saveFailed:
            return "Failed to save configuration"
        case .loadFailed:
            return "Failed to load configuration"
        case .fourEyesApprovalRequired(let requestId):
            return "This configuration change requires 4-eyes approval. Request ID: \(requestId)"
        case .noBackendConnection:
            return "No backend connection available for configuration change"
        case .approvalRejected(let reason):
            return "Configuration change was rejected: \(reason)"
        }
    }

    /// Returns true if this error indicates a 4-eyes approval is pending
    var isPendingApproval: Bool {
        if case .fourEyesApprovalRequired = self {
            return true
        }
        return false
    }

    /// Returns the request ID if this is a 4-eyes approval error
    var fourEyesRequestId: String? {
        if case .fourEyesApprovalRequired(let requestId) = self {
            return requestId
        }
        return nil
    }
}
