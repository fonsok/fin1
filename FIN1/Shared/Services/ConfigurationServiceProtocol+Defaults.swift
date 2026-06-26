import Foundation

extension ConfigurationServiceProtocol {
    func approveConfigurationChange(requestId: String, notes: String?) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }

    func rejectConfigurationChange(requestId: String, reason: String) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }

    func refreshConfigurationFromServerIfAvailable() async {
        // Default: no remote client (tests / previews). `ConfigurationService` overrides.
    }

    var traderCommissionPercentage: String {
        Self.formatCommissionPercent(traderCommissionRate)
    }

    var investorCommissionPercentage: String {
        Self.formatCommissionPercent(self.effectiveInvestorCommissionRate)
    }

    var appCommissionPercentage: String {
        Self.formatCommissionPercent(self.appCommissionRate)
    }

    private static func formatCommissionPercent(_ rate: Double) -> String {
        let percent = (rate * 100).formatted(.number.precision(.fractionLength(0...2)))
        return "\(percent)%"
    }

    var effectiveCommissionRate: Double { traderCommissionRate }

    var appCommissionRate: Double { CalculationConstants.FeeRates.appCommissionRate }

    var investorCommissionRateTotal: Double { CalculationConstants.FeeRates.investorCommissionRateTotal }

    var effectiveInvestorCommissionRate: Double { self.investorCommissionRateTotal }

    var appServiceChargePercentage: String {
        "\((appServiceChargeRate * 100).formatted(.number.precision(.fractionLength(2))))%"
    }

    var appServiceChargeRateCompanies: Double { appServiceChargeRate }
    var effectiveAppServiceChargeRate: Double { appServiceChargeRate }

    func effectiveAppServiceChargeRate(for accountTypeRaw: String?) -> Double {
        if accountTypeRaw?.lowercased() == "company" {
            return self.appServiceChargeRateCompanies
        }
        return appServiceChargeRate
    }

    var dailyTransactionLimit: Double { CalculationConstants.TransactionLimits.baseDailyLimit }
    var weeklyTransactionLimit: Double { CalculationConstants.TransactionLimits.baseWeeklyLimit }
    var monthlyTransactionLimit: Double { CalculationConstants.TransactionLimits.baseMonthlyLimit }
    var minimumInvestmentAmount: Double { CalculationConstants.Investment.fallbackMinimumInvestmentAmount }
    var maximumInvestmentAmount: Double { CalculationConstants.Investment.fallbackMaximumInvestmentAmount }
    var maxTraderPartialSells: Int { 3 }
    var effectiveMaxTraderPartialSells: Int { min(3, max(0, self.maxTraderPartialSells)) }
    var taxCollectionMode: TaxCollectionMode { .customerSelfReports }
    var showInvestorPartialSellRealizations: Bool { false }
    var showTraderDashboardInvestmentActiveStatus: Bool { true }
    var serviceChargeInvoiceFromBackend: Bool { true }
    var serviceChargeLegacyClientFallbackEnabled: Bool { false }
    var investorMonetaryServerOnly: Bool { true }
    var collectionBillServerLegs: Bool { true }
    var traderMonetaryServerOnly: Bool { true }
    var frontendReadonlyMode: Bool { false }
    var showDocumentReferenceLinksInAccountStatement: Bool { true }

    func updateShowDocumentReferenceLinksInAccountStatement(_ value: Bool) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }
}
