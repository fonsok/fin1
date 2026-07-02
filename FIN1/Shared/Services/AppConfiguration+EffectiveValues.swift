import Foundation

extension AppConfiguration {
    var effectiveTraderCommissionRate: Double { self.traderCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate }
    var effectiveAppCommissionRate: Double { self.appCommissionRate ?? CalculationConstants.FeeRates.appCommissionRate }
    var effectiveInvestorCommissionRateTotal: Double {
        self.investorCommissionRateTotal ?? CalculationConstants.FeeRates.investorCommissionRateTotal
    }
    var effectiveInvestorCommissionRate: Double { self.effectiveInvestorCommissionRateTotal }
    var effectiveAppServiceChargeRate: Double { self.appServiceChargeRate ?? CalculationConstants.ServiceCharges.appServiceChargeRate }
    var effectiveAppServiceChargeRateCompanies: Double { self.appServiceChargeRateCompanies ?? self.effectiveAppServiceChargeRate }
    var effectiveMaximumRiskExposurePercent: Double { self.maximumRiskExposurePercent ?? 2.0 }
    var effectiveShowDocumentReferenceLinksInAccountStatement: Bool { self.showDocumentReferenceLinksInAccountStatement ?? true }
    var effectiveWalletFeatureEnabled: Bool { self.walletFeatureEnabled ?? false }
    var effectiveServiceChargeInvoiceFromBackend: Bool { self.serviceChargeInvoiceFromBackend ?? true }
    var effectiveServiceChargeLegacyClientFallbackEnabled: Bool { self.serviceChargeLegacyClientFallbackEnabled ?? false }
    var effectiveInvestorMonetaryServerOnly: Bool { self.investorMonetaryServerOnly ?? true }
    var effectiveCollectionBillServerLegs: Bool { self.collectionBillServerLegs ?? true }
    var effectiveTraderMonetaryServerOnly: Bool { self.traderMonetaryServerOnly ?? true }
    var effectiveFrontendReadonlyMode: Bool { self.frontendReadonlyMode ?? false }
    var effectiveShowInvestorPartialSellRealizations: Bool { self.showInvestorPartialSellRealizations ?? false }
    var effectiveShowTraderDashboardInvestmentActiveStatus: Bool { self.showTraderDashboardInvestmentActiveStatus ?? true }
    var effectiveDailyTransactionLimit: Double { self.dailyTransactionLimit ?? CalculationConstants.TransactionLimits.baseDailyLimit }
    var effectiveWeeklyTransactionLimit: Double { self.weeklyTransactionLimit ?? CalculationConstants.TransactionLimits.baseWeeklyLimit }
    var effectiveMonthlyTransactionLimit: Double { self.monthlyTransactionLimit ?? CalculationConstants.TransactionLimits.baseMonthlyLimit }
    var effectiveMinimumInvestment: Double { self.minInvestment ?? CalculationConstants.Investment.fallbackMinimumInvestmentAmount }
    var effectiveMaximumInvestment: Double { self.maxInvestment ?? CalculationConstants.Investment.fallbackMaximumInvestmentAmount }
    var effectiveMinTraderBuyOrderAmount: Double {
        guard let raw = self.minTraderBuyOrderAmount else {
            return CalculationConstants.TraderBuyOrder.fallbackMinimumBuyOrderAmount
        }
        return max(0, raw)
    }
    var effectiveMaxTraderPartialSells: Int {
        let raw = self.maxTraderPartialSells ?? 3
        return min(3, max(0, raw))
    }
    var effectiveTaxCollectionMode: TaxCollectionMode {
        TaxCollectionMode(rawConfigValue: self.taxCollectionMode)
    }
}
