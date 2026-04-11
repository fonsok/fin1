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
    var appServiceChargeRate: Double { get }
    var appServiceChargePercentage: String { get }

    /// Single source of truth for commission rate with fallback to default
    /// Use this instead of manually checking `traderCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate`
    var effectiveCommissionRate: Double { get }

    /// Single source of truth for app service charge rate with fallback to default
    /// Use this instead of manually checking `appServiceChargeRate ?? CalculationConstants.ServiceCharges.appServiceChargeRate`
    var effectiveAppServiceChargeRate: Double { get }

    /// Admin-configurable daily transaction limit (EUR), independent of risk class.
    /// Source of truth is the backend Configuration; CalculationConstants is fallback only.
    var dailyTransactionLimit: Double { get }

    /// Admin-configurable weekly transaction limit (EUR), independent of risk class.
    var weeklyTransactionLimit: Double { get }

    /// Admin-configurable monthly transaction limit (EUR), independent of risk class.
    var monthlyTransactionLimit: Double { get }

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
    func updateAppServiceChargeRate(_ rate: Double) async throws
    func updateSLAMonitoringInterval(_ interval: TimeInterval) async throws
    func resetToDefaults() async throws

    // MARK: - Validation
    func validateMinimumCashReserve(_ value: Double) -> Bool
    func validateInitialAccountBalance(_ value: Double) -> Bool
    func validatePoolBalanceDistributionThreshold(_ value: Double) -> Bool
    func validateTraderCommissionRate(_ rate: Double) -> Bool
    func validateMaximumRiskExposurePercent(_ value: Double) -> Bool
    func validateAppServiceChargeRate(_ rate: Double) -> Bool
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

    /// Returns the app service charge percentage as a formatted string (e.g., "2%")
    var appServiceChargePercentage: String {
        "\((appServiceChargeRate * 100).formatted(.number.precision(.fractionLength(2))))%"
    }

    /// Single source of truth for app service charge rate
    /// Always use this instead of manually checking with fallback
    var effectiveAppServiceChargeRate: Double {
        appServiceChargeRate
    }

    /// Default implementation for daily transaction limit with documented fallback.
    /// Backend configuration is authoritative; this exists only for cold-start / tests.
    var dailyTransactionLimit: Double {
        CalculationConstants.TransactionLimits.baseDailyLimit
    }

    /// Default implementation for weekly transaction limit with documented fallback.
    var weeklyTransactionLimit: Double {
        CalculationConstants.TransactionLimits.baseWeeklyLimit
    }

    /// Default implementation for monthly transaction limit with documented fallback.
    var monthlyTransactionLimit: Double {
        CalculationConstants.TransactionLimits.baseMonthlyLimit
    }
}

// MARK: - Configuration Models
struct AppConfiguration: Codable {
    var minimumCashReserve: Double
    var initialAccountBalance: Double
    var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy
    var poolBalanceDistributionThreshold: Double
    var traderCommissionRate: Double?
    var appServiceChargeRate: Double?
    var showCommissionBreakdownInCreditNote: Bool?
    /// Maximum recommended risk exposure as percentage of assets (e.g. 2.0 = 2%). Shown on dashboard.
    var maximumRiskExposurePercent: Double?
    /// When false, Wallet (crypto) UI is hidden. Managed via admin portal.
    var walletFeatureEnabled: Bool?
    /// Admin-configurable daily transaction limit (EUR). When nil, falls back to CalculationConstants.
    var dailyTransactionLimit: Double?
    /// Admin-configurable weekly transaction limit (EUR).
    var weeklyTransactionLimit: Double?
    /// Admin-configurable monthly transaction limit (EUR).
    var monthlyTransactionLimit: Double?
    var userMinimumCashReserves: [String: Double]
    var slaMonitoringInterval: TimeInterval
    var lastUpdated: Date
    var updatedBy: String

    enum CodingKeys: String, CodingKey {
        case minimumCashReserve
        case initialAccountBalance
        case poolBalanceDistributionStrategy
        case poolBalanceDistributionThreshold
        case traderCommissionRate
        case appServiceChargeRate
        case platformServiceChargeRate // legacy decode support
        case showCommissionBreakdownInCreditNote
        case maximumRiskExposurePercent
        case walletFeatureEnabled
        case dailyTransactionLimit
        case weeklyTransactionLimit
        case monthlyTransactionLimit
        case userMinimumCashReserves
        case slaMonitoringInterval
        case lastUpdated
        case updatedBy
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        minimumCashReserve = try c.decode(Double.self, forKey: .minimumCashReserve)
        initialAccountBalance = try c.decode(Double.self, forKey: .initialAccountBalance)
        poolBalanceDistributionStrategy = try c.decode(PoolBalanceDistributionStrategy.self, forKey: .poolBalanceDistributionStrategy)
        poolBalanceDistributionThreshold = try c.decode(Double.self, forKey: .poolBalanceDistributionThreshold)
        traderCommissionRate = try c.decodeIfPresent(Double.self, forKey: .traderCommissionRate)

        // Backward compatibility: accept legacy key if present.
        appServiceChargeRate =
            try c.decodeIfPresent(Double.self, forKey: .appServiceChargeRate)
            ?? c.decodeIfPresent(Double.self, forKey: .platformServiceChargeRate)

        showCommissionBreakdownInCreditNote = try c.decodeIfPresent(Bool.self, forKey: .showCommissionBreakdownInCreditNote)
        maximumRiskExposurePercent = try c.decodeIfPresent(Double.self, forKey: .maximumRiskExposurePercent)
        walletFeatureEnabled = try c.decodeIfPresent(Bool.self, forKey: .walletFeatureEnabled)
        dailyTransactionLimit = try c.decodeIfPresent(Double.self, forKey: .dailyTransactionLimit)
        weeklyTransactionLimit = try c.decodeIfPresent(Double.self, forKey: .weeklyTransactionLimit)
        monthlyTransactionLimit = try c.decodeIfPresent(Double.self, forKey: .monthlyTransactionLimit)
        userMinimumCashReserves = try c.decode([String: Double].self, forKey: .userMinimumCashReserves)
        slaMonitoringInterval = try c.decode(TimeInterval.self, forKey: .slaMonitoringInterval)
        lastUpdated = try c.decode(Date.self, forKey: .lastUpdated)
        updatedBy = try c.decode(String.self, forKey: .updatedBy)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(minimumCashReserve, forKey: .minimumCashReserve)
        try c.encode(initialAccountBalance, forKey: .initialAccountBalance)
        try c.encode(poolBalanceDistributionStrategy, forKey: .poolBalanceDistributionStrategy)
        try c.encode(poolBalanceDistributionThreshold, forKey: .poolBalanceDistributionThreshold)
        try c.encodeIfPresent(traderCommissionRate, forKey: .traderCommissionRate)
        try c.encodeIfPresent(appServiceChargeRate, forKey: .appServiceChargeRate)
        try c.encodeIfPresent(showCommissionBreakdownInCreditNote, forKey: .showCommissionBreakdownInCreditNote)
        try c.encodeIfPresent(maximumRiskExposurePercent, forKey: .maximumRiskExposurePercent)
        try c.encodeIfPresent(walletFeatureEnabled, forKey: .walletFeatureEnabled)
        try c.encodeIfPresent(dailyTransactionLimit, forKey: .dailyTransactionLimit)
        try c.encodeIfPresent(weeklyTransactionLimit, forKey: .weeklyTransactionLimit)
        try c.encodeIfPresent(monthlyTransactionLimit, forKey: .monthlyTransactionLimit)
        try c.encode(userMinimumCashReserves, forKey: .userMinimumCashReserves)
        try c.encode(slaMonitoringInterval, forKey: .slaMonitoringInterval)
        try c.encode(lastUpdated, forKey: .lastUpdated)
        try c.encode(updatedBy, forKey: .updatedBy)
    }

    init(
        minimumCashReserve: Double,
        initialAccountBalance: Double,
        poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy,
        poolBalanceDistributionThreshold: Double,
        traderCommissionRate: Double?,
        appServiceChargeRate: Double?,
        showCommissionBreakdownInCreditNote: Bool?,
        maximumRiskExposurePercent: Double?,
        walletFeatureEnabled: Bool?,
        dailyTransactionLimit: Double?,
        weeklyTransactionLimit: Double?,
        monthlyTransactionLimit: Double?,
        userMinimumCashReserves: [String: Double],
        slaMonitoringInterval: TimeInterval,
        lastUpdated: Date,
        updatedBy: String
    ) {
        self.minimumCashReserve = minimumCashReserve
        self.initialAccountBalance = initialAccountBalance
        self.poolBalanceDistributionStrategy = poolBalanceDistributionStrategy
        self.poolBalanceDistributionThreshold = poolBalanceDistributionThreshold
        self.traderCommissionRate = traderCommissionRate
        self.appServiceChargeRate = appServiceChargeRate
        self.showCommissionBreakdownInCreditNote = showCommissionBreakdownInCreditNote
        self.maximumRiskExposurePercent = maximumRiskExposurePercent
        self.walletFeatureEnabled = walletFeatureEnabled
        self.dailyTransactionLimit = dailyTransactionLimit
        self.weeklyTransactionLimit = weeklyTransactionLimit
        self.monthlyTransactionLimit = monthlyTransactionLimit
        self.userMinimumCashReserves = userMinimumCashReserves
        self.slaMonitoringInterval = slaMonitoringInterval
        self.lastUpdated = lastUpdated
        self.updatedBy = updatedBy
    }

    static let `default` = AppConfiguration(
        minimumCashReserve: 20.0,
        initialAccountBalance: 0.0,
        poolBalanceDistributionStrategy: .immediateDistribution,
        poolBalanceDistributionThreshold: 5.0,
        traderCommissionRate: 0.10,
        appServiceChargeRate: 0.02,
        showCommissionBreakdownInCreditNote: true,
        maximumRiskExposurePercent: 2.0,
        walletFeatureEnabled: false,
        dailyTransactionLimit: CalculationConstants.TransactionLimits.baseDailyLimit,
        weeklyTransactionLimit: CalculationConstants.TransactionLimits.baseWeeklyLimit,
        monthlyTransactionLimit: CalculationConstants.TransactionLimits.baseMonthlyLimit,
        userMinimumCashReserves: [:],
        slaMonitoringInterval: 300.0,
        lastUpdated: Date(),
        updatedBy: "system"
    )

    // Computed property to get commission rate with fallback
    var effectiveTraderCommissionRate: Double {
        traderCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate
    }

    // Computed property to get app service charge rate with fallback
    var effectiveAppServiceChargeRate: Double {
        appServiceChargeRate ?? CalculationConstants.ServiceCharges.appServiceChargeRate
    }

    /// Maximum risk exposure percent with fallback (e.g. 2.0 for 2%).
    var effectiveMaximumRiskExposurePercent: Double {
        maximumRiskExposurePercent ?? 2.0
    }

    /// Wallet feature enabled with fallback (default off until crypto is supported).
    var effectiveWalletFeatureEnabled: Bool {
        walletFeatureEnabled ?? false
    }

    /// Effective daily transaction limit with fallback to CalculationConstants.
    var effectiveDailyTransactionLimit: Double {
        dailyTransactionLimit ?? CalculationConstants.TransactionLimits.baseDailyLimit
    }

    /// Effective weekly transaction limit with fallback.
    var effectiveWeeklyTransactionLimit: Double {
        weeklyTransactionLimit ?? CalculationConstants.TransactionLimits.baseWeeklyLimit
    }

    /// Effective monthly transaction limit with fallback.
    var effectiveMonthlyTransactionLimit: Double {
        monthlyTransactionLimit ?? CalculationConstants.TransactionLimits.baseMonthlyLimit
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
