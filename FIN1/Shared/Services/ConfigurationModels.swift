import Foundation

// MARK: - Configuration Models
struct AppConfiguration: Codable {
    var minimumCashReserve: Double
    var initialAccountBalance: Double
    var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy
    var poolBalanceDistributionThreshold: Double
    var traderCommissionRate: Double?
    var appServiceChargeRate: Double?
    var appServiceChargeRateCompanies: Double?
    var showCommissionBreakdownInCreditNote: Bool?
    var showDocumentReferenceLinksInAccountStatement: Bool?
    var maximumRiskExposurePercent: Double?
    var walletFeatureEnabled: Bool?
    var serviceChargeInvoiceFromBackend: Bool?
    var serviceChargeLegacyClientFallbackEnabled: Bool?
    var dailyTransactionLimit: Double?
    var weeklyTransactionLimit: Double?
    var monthlyTransactionLimit: Double?
    var minInvestment: Double?
    var maxInvestment: Double?
    var userMinimumCashReserves: [String: Double]
    var slaMonitoringInterval: TimeInterval
    var lastUpdated: Date
    var updatedBy: String

    enum CodingKeys: String, CodingKey {
        case minimumCashReserve, initialAccountBalance, poolBalanceDistributionStrategy, poolBalanceDistributionThreshold
        case traderCommissionRate, appServiceChargeRate, appServiceChargeRateCompanies
        case platformServiceChargeRate, platformServiceChargeRateCompanies
        case showCommissionBreakdownInCreditNote, showDocumentReferenceLinksInAccountStatement
        case maximumRiskExposurePercent, walletFeatureEnabled
        case serviceChargeInvoiceFromBackend, serviceChargeLegacyClientFallbackEnabled
        case dailyTransactionLimit, weeklyTransactionLimit, monthlyTransactionLimit
        case minInvestment, maxInvestment, userMinimumCashReserves, slaMonitoringInterval, lastUpdated, updatedBy
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        minimumCashReserve = try c.decode(Double.self, forKey: .minimumCashReserve)
        initialAccountBalance = try c.decode(Double.self, forKey: .initialAccountBalance)
        poolBalanceDistributionStrategy = try c.decode(PoolBalanceDistributionStrategy.self, forKey: .poolBalanceDistributionStrategy)
        poolBalanceDistributionThreshold = try c.decode(Double.self, forKey: .poolBalanceDistributionThreshold)
        traderCommissionRate = try c.decodeIfPresent(Double.self, forKey: .traderCommissionRate)
        appServiceChargeRate = try c.decodeIfPresent(Double.self, forKey: .appServiceChargeRate)
            ?? c.decodeIfPresent(Double.self, forKey: .platformServiceChargeRate)
        appServiceChargeRateCompanies = try c.decodeIfPresent(Double.self, forKey: .appServiceChargeRateCompanies)
            ?? c.decodeIfPresent(Double.self, forKey: .platformServiceChargeRateCompanies)
            ?? appServiceChargeRate
        showCommissionBreakdownInCreditNote = try c.decodeIfPresent(Bool.self, forKey: .showCommissionBreakdownInCreditNote)
        showDocumentReferenceLinksInAccountStatement = try c.decodeIfPresent(Bool.self, forKey: .showDocumentReferenceLinksInAccountStatement)
        maximumRiskExposurePercent = try c.decodeIfPresent(Double.self, forKey: .maximumRiskExposurePercent)
        walletFeatureEnabled = try c.decodeIfPresent(Bool.self, forKey: .walletFeatureEnabled)
        serviceChargeInvoiceFromBackend = try c.decodeIfPresent(Bool.self, forKey: .serviceChargeInvoiceFromBackend)
        serviceChargeLegacyClientFallbackEnabled = try c.decodeIfPresent(Bool.self, forKey: .serviceChargeLegacyClientFallbackEnabled)
        dailyTransactionLimit = try c.decodeIfPresent(Double.self, forKey: .dailyTransactionLimit)
        weeklyTransactionLimit = try c.decodeIfPresent(Double.self, forKey: .weeklyTransactionLimit)
        monthlyTransactionLimit = try c.decodeIfPresent(Double.self, forKey: .monthlyTransactionLimit)
        minInvestment = try c.decodeIfPresent(Double.self, forKey: .minInvestment)
        maxInvestment = try c.decodeIfPresent(Double.self, forKey: .maxInvestment)
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
        try c.encodeIfPresent(appServiceChargeRateCompanies, forKey: .appServiceChargeRateCompanies)
        try c.encodeIfPresent(showCommissionBreakdownInCreditNote, forKey: .showCommissionBreakdownInCreditNote)
        try c.encodeIfPresent(showDocumentReferenceLinksInAccountStatement, forKey: .showDocumentReferenceLinksInAccountStatement)
        try c.encodeIfPresent(maximumRiskExposurePercent, forKey: .maximumRiskExposurePercent)
        try c.encodeIfPresent(walletFeatureEnabled, forKey: .walletFeatureEnabled)
        try c.encodeIfPresent(serviceChargeInvoiceFromBackend, forKey: .serviceChargeInvoiceFromBackend)
        try c.encodeIfPresent(serviceChargeLegacyClientFallbackEnabled, forKey: .serviceChargeLegacyClientFallbackEnabled)
        try c.encodeIfPresent(dailyTransactionLimit, forKey: .dailyTransactionLimit)
        try c.encodeIfPresent(weeklyTransactionLimit, forKey: .weeklyTransactionLimit)
        try c.encodeIfPresent(monthlyTransactionLimit, forKey: .monthlyTransactionLimit)
        try c.encodeIfPresent(minInvestment, forKey: .minInvestment)
        try c.encodeIfPresent(maxInvestment, forKey: .maxInvestment)
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
        appServiceChargeRateCompanies: Double?,
        showCommissionBreakdownInCreditNote: Bool?,
        showDocumentReferenceLinksInAccountStatement: Bool?,
        maximumRiskExposurePercent: Double?,
        walletFeatureEnabled: Bool?,
        serviceChargeInvoiceFromBackend: Bool? = nil,
        serviceChargeLegacyClientFallbackEnabled: Bool? = nil,
        dailyTransactionLimit: Double?,
        weeklyTransactionLimit: Double?,
        monthlyTransactionLimit: Double?,
        minInvestment: Double?,
        maxInvestment: Double?,
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
        self.appServiceChargeRateCompanies = appServiceChargeRateCompanies
        self.showCommissionBreakdownInCreditNote = showCommissionBreakdownInCreditNote
        self.showDocumentReferenceLinksInAccountStatement = showDocumentReferenceLinksInAccountStatement
        self.maximumRiskExposurePercent = maximumRiskExposurePercent
        self.walletFeatureEnabled = walletFeatureEnabled
        self.serviceChargeInvoiceFromBackend = serviceChargeInvoiceFromBackend
        self.serviceChargeLegacyClientFallbackEnabled = serviceChargeLegacyClientFallbackEnabled
        self.dailyTransactionLimit = dailyTransactionLimit
        self.weeklyTransactionLimit = weeklyTransactionLimit
        self.monthlyTransactionLimit = monthlyTransactionLimit
        self.minInvestment = minInvestment
        self.maxInvestment = maxInvestment
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
        appServiceChargeRateCompanies: 0.02,
        showCommissionBreakdownInCreditNote: true,
        showDocumentReferenceLinksInAccountStatement: true,
        maximumRiskExposurePercent: 2.0,
        walletFeatureEnabled: false,
        serviceChargeLegacyClientFallbackEnabled: true,
        dailyTransactionLimit: CalculationConstants.TransactionLimits.baseDailyLimit,
        weeklyTransactionLimit: CalculationConstants.TransactionLimits.baseWeeklyLimit,
        monthlyTransactionLimit: CalculationConstants.TransactionLimits.baseMonthlyLimit,
        minInvestment: nil,
        maxInvestment: nil,
        userMinimumCashReserves: [:],
        slaMonitoringInterval: 300.0,
        lastUpdated: Date(),
        updatedBy: "system"
    )

    var effectiveTraderCommissionRate: Double { traderCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate }
    var effectiveAppServiceChargeRate: Double { appServiceChargeRate ?? CalculationConstants.ServiceCharges.appServiceChargeRate }
    var effectiveAppServiceChargeRateCompanies: Double { appServiceChargeRateCompanies ?? effectiveAppServiceChargeRate }
    var effectiveMaximumRiskExposurePercent: Double { maximumRiskExposurePercent ?? 2.0 }
    var effectiveShowDocumentReferenceLinksInAccountStatement: Bool { showDocumentReferenceLinksInAccountStatement ?? true }
    var effectiveWalletFeatureEnabled: Bool { walletFeatureEnabled ?? false }
    var effectiveServiceChargeInvoiceFromBackend: Bool { serviceChargeInvoiceFromBackend ?? false }
    var effectiveServiceChargeLegacyClientFallbackEnabled: Bool { serviceChargeLegacyClientFallbackEnabled ?? true }
    var effectiveDailyTransactionLimit: Double { dailyTransactionLimit ?? CalculationConstants.TransactionLimits.baseDailyLimit }
    var effectiveWeeklyTransactionLimit: Double { weeklyTransactionLimit ?? CalculationConstants.TransactionLimits.baseWeeklyLimit }
    var effectiveMonthlyTransactionLimit: Double { monthlyTransactionLimit ?? CalculationConstants.TransactionLimits.baseMonthlyLimit }
    var effectiveMinimumInvestment: Double { minInvestment ?? CalculationConstants.Investment.fallbackMinimumInvestmentAmount }
    var effectiveMaximumInvestment: Double { maxInvestment ?? CalculationConstants.Investment.fallbackMaximumInvestmentAmount }
}

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
        case .invalidValue(let message): return "Invalid configuration value: \(message)"
        case .unauthorizedAccess: return "Unauthorized access to configuration settings"
        case .saveFailed: return "Failed to save configuration"
        case .loadFailed: return "Failed to load configuration"
        case .fourEyesApprovalRequired(let requestId): return "This configuration change requires 4-eyes approval. Request ID: \(requestId)"
        case .noBackendConnection: return "No backend connection available for configuration change"
        case .approvalRejected(let reason): return "Configuration change was rejected: \(reason)"
        }
    }

    var isPendingApproval: Bool {
        if case .fourEyesApprovalRequired = self { return true }
        return false
    }

    var fourEyesRequestId: String? {
        if case .fourEyesApprovalRequired(let requestId) = self { return requestId }
        return nil
    }
}
