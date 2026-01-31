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
    var minimumCashReserve: Double { get }
    var initialAccountBalance: Double { get }
    var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy { get }
    var poolBalanceDistributionThreshold: Double { get }
    var traderCommissionRate: Double { get }
    var traderCommissionPercentage: String { get }

    /// Single source of truth for commission rate with fallback to default
    /// Use this instead of manually checking `traderCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate`
    var effectiveCommissionRate: Double { get }

    var isAdminMode: Bool { get }

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
    func updateSLAMonitoringInterval(_ interval: TimeInterval) async throws
    func resetToDefaults() async throws

    // MARK: - Validation
    func validateMinimumCashReserve(_ value: Double) -> Bool
    func validateInitialAccountBalance(_ value: Double) -> Bool
    func validatePoolBalanceDistributionThreshold(_ value: Double) -> Bool
    func validateTraderCommissionRate(_ rate: Double) -> Bool
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
}

// MARK: - Configuration Models
struct AppConfiguration: Codable {
    var minimumCashReserve: Double
    var initialAccountBalance: Double
    var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy
    var poolBalanceDistributionThreshold: Double
    var traderCommissionRate: Double?
    var userMinimumCashReserves: [String: Double] // userId -> minimumCashReserve
    var slaMonitoringInterval: TimeInterval // SLA monitoring check interval in seconds
    var lastUpdated: Date
    var updatedBy: String // User ID who made the change

    static let `default` = AppConfiguration(
        minimumCashReserve: 12.0,
        initialAccountBalance: 50000.0,
        poolBalanceDistributionStrategy: .immediateDistribution,
        poolBalanceDistributionThreshold: 5.0,
        traderCommissionRate: 0.10, // 10% - matches CalculationConstants default
        userMinimumCashReserves: [:],
        slaMonitoringInterval: 300.0, // 5 minutes default
        lastUpdated: Date(),
        updatedBy: "system"
    )

    // Computed property to get commission rate with fallback
    var effectiveTraderCommissionRate: Double {
        traderCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate
    }
}

// MARK: - Configuration Errors
enum ConfigurationError: Error, LocalizedError {
    case invalidValue(String)
    case unauthorizedAccess
    case saveFailed
    case loadFailed

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
        }
    }
}
