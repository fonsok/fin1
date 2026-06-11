import Foundation

// MARK: - Configuration Models
struct AppConfiguration: Codable {
    var minimumCashReserve: Double
    var initialAccountBalance: Double
    var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy
    var poolBalanceDistributionThreshold: Double
    var traderCommissionRate: Double?
    var appCommissionRate: Double?
    /// Exact investor commission sum (= trader + app); admin SSOT for Collection Bill rate line.
    var investorCommissionRateTotal: Double?
    var appServiceChargeRate: Double?
    var appServiceChargeRateCompanies: Double?
    var showCommissionBreakdownInCreditNote: Bool?
    var showDocumentReferenceLinksInAccountStatement: Bool?
    var maximumRiskExposurePercent: Double?
    var walletFeatureEnabled: Bool?
    var serviceChargeInvoiceFromBackend: Bool?
    var serviceChargeLegacyClientFallbackEnabled: Bool?
    var investorMonetaryServerOnly: Bool?
    var showInvestorPartialSellRealizations: Bool?
    var dailyTransactionLimit: Double?
    var weeklyTransactionLimit: Double?
    var monthlyTransactionLimit: Double?
    var minInvestment: Double?
    var maxInvestment: Double?
    /// 0 = no cap; max gross EUR per pool-mirror buy leg / reserved pool per trader (admin).
    var maxPoolMirrorBuyOrderAmount: Double?
    var maxTraderPartialSells: Int?
    /// `customer_self_reports` vs `platform_withholds` — from admin Steuerparameter.
    var taxCollectionMode: String?
    var userMinimumCashReserves: [String: Double]
    var slaMonitoringInterval: TimeInterval
    var lastUpdated: Date
    var updatedBy: String

    enum CodingKeys: String, CodingKey {
        case minimumCashReserve, initialAccountBalance, poolBalanceDistributionStrategy, poolBalanceDistributionThreshold
        case traderCommissionRate, appCommissionRate, investorCommissionRateTotal, appServiceChargeRate, appServiceChargeRateCompanies
        case platformServiceChargeRate, platformServiceChargeRateCompanies
        case showCommissionBreakdownInCreditNote, showDocumentReferenceLinksInAccountStatement
        case maximumRiskExposurePercent, walletFeatureEnabled
        case serviceChargeInvoiceFromBackend, serviceChargeLegacyClientFallbackEnabled, investorMonetaryServerOnly, showInvestorPartialSellRealizations
        case dailyTransactionLimit, weeklyTransactionLimit, monthlyTransactionLimit
        case minInvestment, maxInvestment, maxPoolMirrorBuyOrderAmount, maxTraderPartialSells, taxCollectionMode, userMinimumCashReserves, slaMonitoringInterval, lastUpdated, updatedBy
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.minimumCashReserve = try c.decode(Double.self, forKey: .minimumCashReserve)
        self.initialAccountBalance = try c.decode(Double.self, forKey: .initialAccountBalance)
        self.poolBalanceDistributionStrategy = try c.decode(PoolBalanceDistributionStrategy.self, forKey: .poolBalanceDistributionStrategy)
        self.poolBalanceDistributionThreshold = try c.decode(Double.self, forKey: .poolBalanceDistributionThreshold)
        self.traderCommissionRate = try c.decodeIfPresent(Double.self, forKey: .traderCommissionRate)
        self.appCommissionRate = try c.decodeIfPresent(Double.self, forKey: .appCommissionRate)
        self.investorCommissionRateTotal = try c.decodeIfPresent(Double.self, forKey: .investorCommissionRateTotal)
        self.appServiceChargeRate = try c.decodeIfPresent(Double.self, forKey: .appServiceChargeRate)
            ?? c.decodeIfPresent(Double.self, forKey: .platformServiceChargeRate)
        self.appServiceChargeRateCompanies = try c.decodeIfPresent(Double.self, forKey: .appServiceChargeRateCompanies)
            ?? c.decodeIfPresent(Double.self, forKey: .platformServiceChargeRateCompanies)
            ?? self.appServiceChargeRate
        self.showCommissionBreakdownInCreditNote = try c.decodeIfPresent(Bool.self, forKey: .showCommissionBreakdownInCreditNote)
        self.showDocumentReferenceLinksInAccountStatement = try c.decodeIfPresent(
            Bool.self,
            forKey: .showDocumentReferenceLinksInAccountStatement
        )
        self.maximumRiskExposurePercent = try c.decodeIfPresent(Double.self, forKey: .maximumRiskExposurePercent)
        self.walletFeatureEnabled = try c.decodeIfPresent(Bool.self, forKey: .walletFeatureEnabled)
        self.serviceChargeInvoiceFromBackend = try c.decodeIfPresent(Bool.self, forKey: .serviceChargeInvoiceFromBackend)
        self.serviceChargeLegacyClientFallbackEnabled = try c.decodeIfPresent(Bool.self, forKey: .serviceChargeLegacyClientFallbackEnabled)
        self.investorMonetaryServerOnly = try c.decodeIfPresent(Bool.self, forKey: .investorMonetaryServerOnly)
        self.showInvestorPartialSellRealizations = try c.decodeIfPresent(Bool.self, forKey: .showInvestorPartialSellRealizations)
        self.dailyTransactionLimit = try c.decodeIfPresent(Double.self, forKey: .dailyTransactionLimit)
        self.weeklyTransactionLimit = try c.decodeIfPresent(Double.self, forKey: .weeklyTransactionLimit)
        self.monthlyTransactionLimit = try c.decodeIfPresent(Double.self, forKey: .monthlyTransactionLimit)
        self.minInvestment = try c.decodeIfPresent(Double.self, forKey: .minInvestment)
        self.maxInvestment = try c.decodeIfPresent(Double.self, forKey: .maxInvestment)
        self.maxPoolMirrorBuyOrderAmount = try c.decodeIfPresent(Double.self, forKey: .maxPoolMirrorBuyOrderAmount)
        self.maxTraderPartialSells = try c.decodeIfPresent(Int.self, forKey: .maxTraderPartialSells)
        self.taxCollectionMode = try c.decodeIfPresent(String.self, forKey: .taxCollectionMode)
        self.userMinimumCashReserves = try c.decode([String: Double].self, forKey: .userMinimumCashReserves)
        self.slaMonitoringInterval = try c.decode(TimeInterval.self, forKey: .slaMonitoringInterval)
        self.lastUpdated = try c.decode(Date.self, forKey: .lastUpdated)
        self.updatedBy = try c.decode(String.self, forKey: .updatedBy)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(self.minimumCashReserve, forKey: .minimumCashReserve)
        try c.encode(self.initialAccountBalance, forKey: .initialAccountBalance)
        try c.encode(self.poolBalanceDistributionStrategy, forKey: .poolBalanceDistributionStrategy)
        try c.encode(self.poolBalanceDistributionThreshold, forKey: .poolBalanceDistributionThreshold)
        try c.encodeIfPresent(self.traderCommissionRate, forKey: .traderCommissionRate)
        try c.encodeIfPresent(self.appCommissionRate, forKey: .appCommissionRate)
        try c.encodeIfPresent(self.investorCommissionRateTotal, forKey: .investorCommissionRateTotal)
        try c.encodeIfPresent(self.appServiceChargeRate, forKey: .appServiceChargeRate)
        try c.encodeIfPresent(self.appServiceChargeRateCompanies, forKey: .appServiceChargeRateCompanies)
        try c.encodeIfPresent(self.showCommissionBreakdownInCreditNote, forKey: .showCommissionBreakdownInCreditNote)
        try c.encodeIfPresent(self.showDocumentReferenceLinksInAccountStatement, forKey: .showDocumentReferenceLinksInAccountStatement)
        try c.encodeIfPresent(self.maximumRiskExposurePercent, forKey: .maximumRiskExposurePercent)
        try c.encodeIfPresent(self.walletFeatureEnabled, forKey: .walletFeatureEnabled)
        try c.encodeIfPresent(self.serviceChargeInvoiceFromBackend, forKey: .serviceChargeInvoiceFromBackend)
        try c.encodeIfPresent(self.serviceChargeLegacyClientFallbackEnabled, forKey: .serviceChargeLegacyClientFallbackEnabled)
        try c.encodeIfPresent(self.investorMonetaryServerOnly, forKey: .investorMonetaryServerOnly)
        try c.encodeIfPresent(self.showInvestorPartialSellRealizations, forKey: .showInvestorPartialSellRealizations)
        try c.encodeIfPresent(self.dailyTransactionLimit, forKey: .dailyTransactionLimit)
        try c.encodeIfPresent(self.weeklyTransactionLimit, forKey: .weeklyTransactionLimit)
        try c.encodeIfPresent(self.monthlyTransactionLimit, forKey: .monthlyTransactionLimit)
        try c.encodeIfPresent(self.minInvestment, forKey: .minInvestment)
        try c.encodeIfPresent(self.maxInvestment, forKey: .maxInvestment)
        try c.encodeIfPresent(self.maxPoolMirrorBuyOrderAmount, forKey: .maxPoolMirrorBuyOrderAmount)
        try c.encodeIfPresent(self.maxTraderPartialSells, forKey: .maxTraderPartialSells)
        try c.encodeIfPresent(self.taxCollectionMode, forKey: .taxCollectionMode)
        try c.encode(self.userMinimumCashReserves, forKey: .userMinimumCashReserves)
        try c.encode(self.slaMonitoringInterval, forKey: .slaMonitoringInterval)
        try c.encode(self.lastUpdated, forKey: .lastUpdated)
        try c.encode(self.updatedBy, forKey: .updatedBy)
    }

    init(
        minimumCashReserve: Double,
        initialAccountBalance: Double,
        poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy,
        poolBalanceDistributionThreshold: Double,
        traderCommissionRate: Double?,
        appCommissionRate: Double? = nil,
        investorCommissionRateTotal: Double? = nil,
        appServiceChargeRate: Double?,
        appServiceChargeRateCompanies: Double?,
        showCommissionBreakdownInCreditNote: Bool?,
        showDocumentReferenceLinksInAccountStatement: Bool?,
        maximumRiskExposurePercent: Double?,
        walletFeatureEnabled: Bool?,
        serviceChargeInvoiceFromBackend: Bool? = nil,
        serviceChargeLegacyClientFallbackEnabled: Bool? = nil,
        investorMonetaryServerOnly: Bool? = nil,
        showInvestorPartialSellRealizations: Bool? = nil,
        dailyTransactionLimit: Double?,
        weeklyTransactionLimit: Double?,
        monthlyTransactionLimit: Double?,
        minInvestment: Double?,
        maxInvestment: Double?,
        maxPoolMirrorBuyOrderAmount: Double? = nil,
        maxTraderPartialSells: Int?,
        taxCollectionMode: String? = nil,
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
        self.appCommissionRate = appCommissionRate
        self.investorCommissionRateTotal = investorCommissionRateTotal
        self.appServiceChargeRate = appServiceChargeRate
        self.appServiceChargeRateCompanies = appServiceChargeRateCompanies
        self.showCommissionBreakdownInCreditNote = showCommissionBreakdownInCreditNote
        self.showDocumentReferenceLinksInAccountStatement = showDocumentReferenceLinksInAccountStatement
        self.maximumRiskExposurePercent = maximumRiskExposurePercent
        self.walletFeatureEnabled = walletFeatureEnabled
        self.serviceChargeInvoiceFromBackend = serviceChargeInvoiceFromBackend
        self.serviceChargeLegacyClientFallbackEnabled = serviceChargeLegacyClientFallbackEnabled
        self.investorMonetaryServerOnly = investorMonetaryServerOnly
        self.showInvestorPartialSellRealizations = showInvestorPartialSellRealizations
        self.dailyTransactionLimit = dailyTransactionLimit
        self.weeklyTransactionLimit = weeklyTransactionLimit
        self.monthlyTransactionLimit = monthlyTransactionLimit
        self.minInvestment = minInvestment
        self.maxInvestment = maxInvestment
        self.maxPoolMirrorBuyOrderAmount = maxPoolMirrorBuyOrderAmount
        self.maxTraderPartialSells = maxTraderPartialSells
        self.taxCollectionMode = taxCollectionMode
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
        traderCommissionRate: 0.05,
        appCommissionRate: 0.05,
        investorCommissionRateTotal: 0.1,
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
        maxTraderPartialSells: 3,
        userMinimumCashReserves: [:],
        slaMonitoringInterval: 300.0,
        lastUpdated: Date(),
        updatedBy: "system"
    )

    var effectiveTraderCommissionRate: Double { self.traderCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate }
    var effectiveAppCommissionRate: Double {
        self.appCommissionRate ?? CalculationConstants.FeeRates.appCommissionRate
    }
    var effectiveInvestorCommissionRateTotal: Double {
        self.investorCommissionRateTotal ?? CalculationConstants.FeeRates.investorCommissionRateTotal
    }
    /// Investor Collection Bill commission line — configured total (= trader + app).
    var effectiveInvestorCommissionRate: Double {
        self.effectiveInvestorCommissionRateTotal
    }
    var effectiveAppServiceChargeRate: Double { self.appServiceChargeRate ?? CalculationConstants.ServiceCharges.appServiceChargeRate }
    var effectiveAppServiceChargeRateCompanies: Double { self.appServiceChargeRateCompanies ?? self.effectiveAppServiceChargeRate }
    var effectiveMaximumRiskExposurePercent: Double { self.maximumRiskExposurePercent ?? 2.0 }
    var effectiveShowDocumentReferenceLinksInAccountStatement: Bool { self.showDocumentReferenceLinksInAccountStatement ?? true }
    var effectiveWalletFeatureEnabled: Bool { self.walletFeatureEnabled ?? false }
    var effectiveServiceChargeInvoiceFromBackend: Bool { self.serviceChargeInvoiceFromBackend ?? false }
    var effectiveServiceChargeLegacyClientFallbackEnabled: Bool { self.serviceChargeLegacyClientFallbackEnabled ?? true }
    var effectiveInvestorMonetaryServerOnly: Bool { self.investorMonetaryServerOnly ?? true }
    var effectiveShowInvestorPartialSellRealizations: Bool { self.showInvestorPartialSellRealizations ?? false }
    var effectiveDailyTransactionLimit: Double { self.dailyTransactionLimit ?? CalculationConstants.TransactionLimits.baseDailyLimit }
    var effectiveWeeklyTransactionLimit: Double { self.weeklyTransactionLimit ?? CalculationConstants.TransactionLimits.baseWeeklyLimit }
    var effectiveMonthlyTransactionLimit: Double { self.monthlyTransactionLimit ?? CalculationConstants.TransactionLimits.baseMonthlyLimit }
    var effectiveMinimumInvestment: Double { self.minInvestment ?? CalculationConstants.Investment.fallbackMinimumInvestmentAmount }
    var effectiveMaximumInvestment: Double { self.maxInvestment ?? CalculationConstants.Investment.fallbackMaximumInvestmentAmount }
    var effectiveMaxTraderPartialSells: Int {
        let raw = self.maxTraderPartialSells ?? 3
        return min(3, max(0, raw))
    }

    var effectiveTaxCollectionMode: TaxCollectionMode {
        TaxCollectionMode(rawConfigValue: self.taxCollectionMode)
    }
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
