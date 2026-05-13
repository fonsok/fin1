import Foundation

extension ConfigurationServiceProtocol {
    func approveConfigurationChange(requestId: String, notes: String?) async throws {
        throw ConfigurationError.noBackendConnection
    }

    func rejectConfigurationChange(requestId: String, reason: String) async throws {
        throw ConfigurationError.noBackendConnection
    }

    func refreshConfigurationFromServerIfAvailable() async {
        // Default: no remote client (tests / previews). `ConfigurationService` overrides.
    }

    var traderCommissionPercentage: String {
        let percent = (traderCommissionRate * 100).formatted(.number.precision(.fractionLength(0...2)))
        return "\(percent)%"
    }

    var effectiveCommissionRate: Double { traderCommissionRate }

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
    var serviceChargeInvoiceFromBackend: Bool { false }
    var serviceChargeLegacyClientFallbackEnabled: Bool { true }
    var showDocumentReferenceLinksInAccountStatement: Bool { true }

    func updateShowDocumentReferenceLinksInAccountStatement(_ value: Bool) async throws {
        // Optional for mock/test conformers.
    }
}
