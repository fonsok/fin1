import Foundation

extension AppConfiguration {
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
        showCommissionBreakdownInCreditNote: false,
        showDocumentReferenceLinksInAccountStatement: true,
        maximumRiskExposurePercent: 2.0,
        walletFeatureEnabled: false,
        serviceChargeInvoiceFromBackend: true,
        serviceChargeLegacyClientFallbackEnabled: false,
        investorMonetaryServerOnly: true,
        collectionBillServerLegs: true,
        traderMonetaryServerOnly: true,
        frontendReadonlyMode: false,
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
}
