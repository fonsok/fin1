import Foundation

// MARK: - Configuration Models
struct AppConfiguration: Codable {
    var minimumCashReserve: Double
    var initialAccountBalance: Double
    var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy
    var poolBalanceDistributionThreshold: Double
    var traderCommissionRate: Double?
    var appCommissionRate: Double?
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
    var collectionBillServerLegs: Bool?
    var traderMonetaryServerOnly: Bool?
    var frontendReadonlyMode: Bool?
    var showInvestorPartialSellRealizations: Bool?
    var showTraderDashboardInvestmentActiveStatus: Bool?
    var dailyTransactionLimit: Double?
    var weeklyTransactionLimit: Double?
    var monthlyTransactionLimit: Double?
    var minInvestment: Double?
    var maxInvestment: Double?
    var maxPoolMirrorBuyOrderAmount: Double?
    var minTraderBuyOrderAmount: Double?
    var maxTraderPartialSells: Int?
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
        case serviceChargeInvoiceFromBackend, serviceChargeLegacyClientFallbackEnabled, investorMonetaryServerOnly, collectionBillServerLegs, traderMonetaryServerOnly, frontendReadonlyMode, showInvestorPartialSellRealizations, showTraderDashboardInvestmentActiveStatus
        case dailyTransactionLimit, weeklyTransactionLimit, monthlyTransactionLimit
        case minInvestment, maxInvestment, maxPoolMirrorBuyOrderAmount, minTraderBuyOrderAmount, maxTraderPartialSells, taxCollectionMode, userMinimumCashReserves, slaMonitoringInterval, lastUpdated, updatedBy
    }
}
