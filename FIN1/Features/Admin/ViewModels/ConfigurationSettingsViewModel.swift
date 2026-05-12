import Foundation
import SwiftUI

// MARK: - Configuration Settings ViewModel
@MainActor
final class ConfigurationSettingsViewModel: ObservableObject {
    private var configurationService: (any ConfigurationServiceProtocol)?

    @Published var minimumCashReserveInput: Double = 20.0
    @Published var initialAccountBalanceInput: Double = 0.0
    @Published var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy = .immediateDistribution
    @Published var poolBalanceDistributionThresholdInput: Double = 5.0
    @Published var traderCommissionRateInput: Double = 0.10
    @Published var showCommissionBreakdownInCreditNoteInput: Bool = true
    @Published var showDocumentReferenceLinksInAccountStatementInput: Bool = true
    @Published var minimumCashReserveError: String?
    @Published var initialAccountBalanceError: String?
    @Published var poolBalanceDistributionThresholdError: String?
    @Published var traderCommissionRateError: String?
    @Published var isLoading: Bool = false

    @Published var traderCommissionRateSuccess: String?
    @Published var initialAccountBalanceSuccess: String?
    @Published var appServiceChargeRateSuccess: String?

    @Published var userMinimumCashReserveUserId: String = ""
    @Published var userMinimumCashReserveInput: Double = 20.0
    @Published var userMinimumCashReserveError: String?

    func configure(with configurationService: any ConfigurationServiceProtocol) {
        self.configurationService = configurationService
        minimumCashReserveInput = configurationService.minimumCashReserve
        initialAccountBalanceInput = configurationService.initialAccountBalance
        poolBalanceDistributionStrategy = configurationService.poolBalanceDistributionStrategy
        poolBalanceDistributionThresholdInput = configurationService.poolBalanceDistributionThreshold
        traderCommissionRateInput = configurationService.traderCommissionRate
        showCommissionBreakdownInCreditNoteInput = configurationService.showCommissionBreakdownInCreditNote
        showDocumentReferenceLinksInAccountStatementInput = configurationService.showDocumentReferenceLinksInAccountStatement
    }

    var currentMinimumCashReserveText: String {
        guard let configurationService else { return formattedCurrency(minimumCashReserveInput) }
        return formattedCurrency(configurationService.minimumCashReserve)
    }

    var currentInitialAccountBalanceText: String {
        guard let configurationService else { return formattedCurrency(initialAccountBalanceInput) }
        return formattedCurrency(configurationService.initialAccountBalance)
    }

    var currentTraderCommissionRateText: String {
        let rate = configurationService?.traderCommissionRate ?? traderCommissionRateInput
        let percent = (rate * 100).formatted(.number.precision(.fractionLength(0...2)))
        return "\(percent)%"
    }

    var currentPoolBalanceDistributionThresholdText: String {
        guard let configurationService else { return formattedCurrency(poolBalanceDistributionThresholdInput) }
        return formattedCurrency(configurationService.poolBalanceDistributionThreshold)
    }

    func currentUserMinimumCashReserveText(for userId: String) -> String? {
        guard !userId.isEmpty, let configurationService else { return nil }
        return configurationService.getMinimumCashReserve(for: userId).formattedAsLocalizedCurrency()
    }

    // MARK: - Formatting Properties

    func formattedCurrency(_ value: Double) -> String {
        value.formattedAsLocalizedCurrency()
    }

    var isValidMinimumCashReserve: Bool {
        return minimumCashReserveInput >= 0.01 && minimumCashReserveInput <= 1000.0
    }

    var isValidInitialAccountBalance: Bool {
        return initialAccountBalanceInput >= 0.0 && initialAccountBalanceInput <= 1_000_000.0
    }

    var isValidPoolBalanceDistributionThreshold: Bool {
        return poolBalanceDistributionThresholdInput >= 1.0 && poolBalanceDistributionThresholdInput <= 100.0
    }

    var isValidTraderCommissionRate: Bool {
        return traderCommissionRateInput >= 0.0 && traderCommissionRateInput <= 1.0
    }

    var isValidUserMinimumCashReserve: Bool {
        return userMinimumCashReserveInput >= 0.01 && userMinimumCashReserveInput <= 1000.0 && !userMinimumCashReserveUserId.isEmpty
    }

    func updateMinimumCashReserve() async {
        guard let configurationService else {
            minimumCashReserveError = "Configuration service unavailable"
            return
        }
        guard isValidMinimumCashReserve else {
            minimumCashReserveError = "Value must be between 0.01 and 1000.0"
            return
        }

        isLoading = true
        minimumCashReserveError = nil

        do {
            try await configurationService.updateMinimumCashReserve(minimumCashReserveInput)
            print("✅ Minimum cash reserve updated to \(minimumCashReserveInput)")
        } catch {
            let appError = error.toAppError()
            minimumCashReserveError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }

        isLoading = false
    }

    func updateInitialAccountBalance() async {
        guard let configurationService else {
            initialAccountBalanceError = "Configuration service unavailable"
            return
        }
        guard isValidInitialAccountBalance else {
            initialAccountBalanceError = "Value must be between 0 and 1000000 EUR"
            return
        }

        isLoading = true
        initialAccountBalanceError = nil
        initialAccountBalanceSuccess = nil

        do {
            try await configurationService.updateInitialAccountBalance(initialAccountBalanceInput)
            print("✅ Initial account balance updated to \(initialAccountBalanceInput)")
            initialAccountBalanceSuccess = "Balance updated successfully"
        } catch let error as ConfigurationError {
            if error.isPendingApproval {
                initialAccountBalanceSuccess = "Change submitted for 4-eyes approval"
                print("⏳ Initial account balance change requires 4-eyes approval")
            } else {
                initialAccountBalanceError = "Failed to update: \(error.localizedDescription)"
            }
        } catch {
            let appError = error.toAppError()
            initialAccountBalanceError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }

        isLoading = false
    }

    func updatePoolBalanceDistributionStrategy() async {
        guard let configurationService else { return }
        isLoading = true

        do {
            try await configurationService.updatePoolBalanceDistributionStrategy(poolBalanceDistributionStrategy)
            print("✅ Pool balance distribution strategy updated to \(poolBalanceDistributionStrategy.displayName)")
        } catch {
            print("❌ Failed to update strategy: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func updatePoolBalanceDistributionThreshold() async {
        guard let configurationService else {
            poolBalanceDistributionThresholdError = "Configuration service unavailable"
            return
        }
        guard isValidPoolBalanceDistributionThreshold else {
            poolBalanceDistributionThresholdError = "Value must be between 1.0 and 100.0"
            return
        }

        isLoading = true
        poolBalanceDistributionThresholdError = nil

        do {
            try await configurationService.updatePoolBalanceDistributionThreshold(poolBalanceDistributionThresholdInput)
            print("✅ Pool balance distribution threshold updated to \(poolBalanceDistributionThresholdInput)")
        } catch {
            let appError = error.toAppError()
            poolBalanceDistributionThresholdError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }

        isLoading = false
    }

    func updateTraderCommissionRate() async {
        guard let configurationService else {
            traderCommissionRateError = "Configuration service unavailable"
            return
        }
        guard isValidTraderCommissionRate else {
            traderCommissionRateError = "Rate must be between 0.0 (0%) and 1.0 (100%)"
            return
        }

        isLoading = true
        traderCommissionRateError = nil
        traderCommissionRateSuccess = nil

        do {
            try await configurationService.updateTraderCommissionRate(traderCommissionRateInput)
            print("✅ Trader commission rate updated to \(traderCommissionRateInput * 100)%")
            traderCommissionRateSuccess = "Rate updated successfully"
        } catch let error as ConfigurationError {
            if error.isPendingApproval {
                traderCommissionRateSuccess = "Change submitted for 4-eyes approval"
                print("⏳ Trader commission rate change requires 4-eyes approval")
            } else {
                traderCommissionRateError = "Failed to update: \(error.localizedDescription)"
            }
        } catch {
            let appError = error.toAppError()
            traderCommissionRateError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }

        isLoading = false
    }

    func updateShowCommissionBreakdownInCreditNote() async {
        guard let configurationService else {
            minimumCashReserveError = "Configuration service unavailable"
            return
        }
        isLoading = true
        do {
            try await configurationService.updateShowCommissionBreakdownInCreditNote(showCommissionBreakdownInCreditNoteInput)
            print("✅ Show commission breakdown in credit note updated to \(showCommissionBreakdownInCreditNoteInput)")
        } catch {
            let appError = error.toAppError()
            minimumCashReserveError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }
        isLoading = false
    }

    func updateShowDocumentReferenceLinksInAccountStatement() async {
        guard let configurationService else {
            minimumCashReserveError = "Configuration service unavailable"
            return
        }
        isLoading = true
        do {
            try await configurationService.updateShowDocumentReferenceLinksInAccountStatement(
                showDocumentReferenceLinksInAccountStatementInput
            )
            print("✅ Show document reference links in account statement updated to \(showDocumentReferenceLinksInAccountStatementInput)")
        } catch {
            let appError = error.toAppError()
            minimumCashReserveError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }
        isLoading = false
    }

    func resetToDefaults() async {
        guard let configurationService else {
            minimumCashReserveError = "Configuration service unavailable"
            return
        }
        isLoading = true
        minimumCashReserveError = nil
        initialAccountBalanceError = nil
        poolBalanceDistributionThresholdError = nil
        traderCommissionRateError = nil

        do {
            try await configurationService.resetToDefaults()
            minimumCashReserveInput = configurationService.minimumCashReserve
            initialAccountBalanceInput = configurationService.initialAccountBalance
            poolBalanceDistributionStrategy = configurationService.poolBalanceDistributionStrategy
            poolBalanceDistributionThresholdInput = configurationService.poolBalanceDistributionThreshold
            traderCommissionRateInput = configurationService.traderCommissionRate
            showCommissionBreakdownInCreditNoteInput = configurationService.showCommissionBreakdownInCreditNote
            showDocumentReferenceLinksInAccountStatementInput = configurationService.showDocumentReferenceLinksInAccountStatement
            print("✅ Configuration reset to defaults")
        } catch {
            let appError = error.toAppError()
            minimumCashReserveError = "Failed to reset: \(appError.errorDescription ?? "An error occurred")"
        }

        isLoading = false
    }

    func updateUserMinimumCashReserve() async {
        guard let configurationService else {
            userMinimumCashReserveError = "Configuration service unavailable"
            return
        }
        guard isValidUserMinimumCashReserve else {
            userMinimumCashReserveError = "User ID is required and value must be between 0.01 and 1000.0"
            return
        }

        isLoading = true
        userMinimumCashReserveError = nil

        do {
            try await configurationService.updateMinimumCashReserve(userMinimumCashReserveInput, for: userMinimumCashReserveUserId)
            print("✅ User \(userMinimumCashReserveUserId) minimum cash reserve updated to \(userMinimumCashReserveInput)")
            userMinimumCashReserveUserId = ""
            userMinimumCashReserveInput = configurationService.minimumCashReserve
        } catch {
            let appError = error.toAppError()
            userMinimumCashReserveError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }

        isLoading = false
    }
}

@available(*, deprecated, renamed: "ConfigurationSettingsViewModel")
typealias ConfigurationManagementViewModel = ConfigurationSettingsViewModel
