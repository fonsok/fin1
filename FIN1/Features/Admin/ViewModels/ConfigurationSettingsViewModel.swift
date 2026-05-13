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
        self.minimumCashReserveInput = configurationService.minimumCashReserve
        self.initialAccountBalanceInput = configurationService.initialAccountBalance
        self.poolBalanceDistributionStrategy = configurationService.poolBalanceDistributionStrategy
        self.poolBalanceDistributionThresholdInput = configurationService.poolBalanceDistributionThreshold
        self.traderCommissionRateInput = configurationService.traderCommissionRate
        self.showCommissionBreakdownInCreditNoteInput = configurationService.showCommissionBreakdownInCreditNote
        self.showDocumentReferenceLinksInAccountStatementInput = configurationService.showDocumentReferenceLinksInAccountStatement
    }

    var currentMinimumCashReserveText: String {
        guard let configurationService else { return self.formattedCurrency(self.minimumCashReserveInput) }
        return self.formattedCurrency(configurationService.minimumCashReserve)
    }

    var currentInitialAccountBalanceText: String {
        guard let configurationService else { return self.formattedCurrency(self.initialAccountBalanceInput) }
        return self.formattedCurrency(configurationService.initialAccountBalance)
    }

    var currentTraderCommissionRateText: String {
        let rate = self.configurationService?.traderCommissionRate ?? self.traderCommissionRateInput
        let percent = (rate * 100).formatted(.number.precision(.fractionLength(0...2)))
        return "\(percent)%"
    }

    var currentPoolBalanceDistributionThresholdText: String {
        guard let configurationService else { return self.formattedCurrency(self.poolBalanceDistributionThresholdInput) }
        return self.formattedCurrency(configurationService.poolBalanceDistributionThreshold)
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
        return self.minimumCashReserveInput >= 0.01 && self.minimumCashReserveInput <= 1_000.0
    }

    var isValidInitialAccountBalance: Bool {
        return self.initialAccountBalanceInput >= 0.0 && self.initialAccountBalanceInput <= 1_000_000.0
    }

    var isValidPoolBalanceDistributionThreshold: Bool {
        return self.poolBalanceDistributionThresholdInput >= 1.0 && self.poolBalanceDistributionThresholdInput <= 100.0
    }

    var isValidTraderCommissionRate: Bool {
        return self.traderCommissionRateInput >= 0.0 && self.traderCommissionRateInput <= 1.0
    }

    var isValidUserMinimumCashReserve: Bool {
        return self.userMinimumCashReserveInput >= 0.01 && self.userMinimumCashReserveInput <= 1_000.0 && !self.userMinimumCashReserveUserId.isEmpty
    }

    func updateMinimumCashReserve() async {
        guard let configurationService else {
            self.minimumCashReserveError = "Configuration service unavailable"
            return
        }
        guard self.isValidMinimumCashReserve else {
            self.minimumCashReserveError = "Value must be between 0.01 and 1000.0"
            return
        }

        self.isLoading = true
        self.minimumCashReserveError = nil

        do {
            try await configurationService.updateMinimumCashReserve(self.minimumCashReserveInput)
            print("✅ Minimum cash reserve updated to \(self.minimumCashReserveInput)")
        } catch {
            let appError = error.toAppError()
            self.minimumCashReserveError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }

        self.isLoading = false
    }

    func updateInitialAccountBalance() async {
        guard let configurationService else {
            self.initialAccountBalanceError = "Configuration service unavailable"
            return
        }
        guard self.isValidInitialAccountBalance else {
            self.initialAccountBalanceError = "Value must be between 0 and 1000000 EUR"
            return
        }

        self.isLoading = true
        self.initialAccountBalanceError = nil
        self.initialAccountBalanceSuccess = nil

        do {
            try await configurationService.updateInitialAccountBalance(self.initialAccountBalanceInput)
            print("✅ Initial account balance updated to \(self.initialAccountBalanceInput)")
            self.initialAccountBalanceSuccess = "Balance updated successfully"
        } catch let error as ConfigurationError {
            if error.isPendingApproval {
                initialAccountBalanceSuccess = "Change submitted for 4-eyes approval"
                print("⏳ Initial account balance change requires 4-eyes approval")
            } else {
                initialAccountBalanceError = "Failed to update: \(error.localizedDescription)"
            }
        } catch {
            let appError = error.toAppError()
            self.initialAccountBalanceError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }

        self.isLoading = false
    }

    func updatePoolBalanceDistributionStrategy() async {
        guard let configurationService else { return }
        self.isLoading = true

        do {
            try await configurationService.updatePoolBalanceDistributionStrategy(self.poolBalanceDistributionStrategy)
            print("✅ Pool balance distribution strategy updated to \(self.poolBalanceDistributionStrategy.displayName)")
        } catch {
            print("❌ Failed to update strategy: \(error.localizedDescription)")
        }

        self.isLoading = false
    }

    func updatePoolBalanceDistributionThreshold() async {
        guard let configurationService else {
            self.poolBalanceDistributionThresholdError = "Configuration service unavailable"
            return
        }
        guard self.isValidPoolBalanceDistributionThreshold else {
            self.poolBalanceDistributionThresholdError = "Value must be between 1.0 and 100.0"
            return
        }

        self.isLoading = true
        self.poolBalanceDistributionThresholdError = nil

        do {
            try await configurationService.updatePoolBalanceDistributionThreshold(self.poolBalanceDistributionThresholdInput)
            print("✅ Pool balance distribution threshold updated to \(self.poolBalanceDistributionThresholdInput)")
        } catch {
            let appError = error.toAppError()
            self.poolBalanceDistributionThresholdError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }

        self.isLoading = false
    }

    func updateTraderCommissionRate() async {
        guard let configurationService else {
            self.traderCommissionRateError = "Configuration service unavailable"
            return
        }
        guard self.isValidTraderCommissionRate else {
            self.traderCommissionRateError = "Rate must be between 0.0 (0%) and 1.0 (100%)"
            return
        }

        self.isLoading = true
        self.traderCommissionRateError = nil
        self.traderCommissionRateSuccess = nil

        do {
            try await configurationService.updateTraderCommissionRate(self.traderCommissionRateInput)
            print("✅ Trader commission rate updated to \(self.traderCommissionRateInput * 100)%")
            self.traderCommissionRateSuccess = "Rate updated successfully"
        } catch let error as ConfigurationError {
            if error.isPendingApproval {
                traderCommissionRateSuccess = "Change submitted for 4-eyes approval"
                print("⏳ Trader commission rate change requires 4-eyes approval")
            } else {
                traderCommissionRateError = "Failed to update: \(error.localizedDescription)"
            }
        } catch {
            let appError = error.toAppError()
            self.traderCommissionRateError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }

        self.isLoading = false
    }

    func updateShowCommissionBreakdownInCreditNote() async {
        guard let configurationService else {
            self.minimumCashReserveError = "Configuration service unavailable"
            return
        }
        self.isLoading = true
        do {
            try await configurationService.updateShowCommissionBreakdownInCreditNote(self.showCommissionBreakdownInCreditNoteInput)
            print("✅ Show commission breakdown in credit note updated to \(self.showCommissionBreakdownInCreditNoteInput)")
        } catch {
            let appError = error.toAppError()
            self.minimumCashReserveError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }
        self.isLoading = false
    }

    func updateShowDocumentReferenceLinksInAccountStatement() async {
        guard let configurationService else {
            self.minimumCashReserveError = "Configuration service unavailable"
            return
        }
        self.isLoading = true
        do {
            try await configurationService.updateShowDocumentReferenceLinksInAccountStatement(
                self.showDocumentReferenceLinksInAccountStatementInput
            )
            print(
                "✅ Show document reference links in account statement updated to \(self.showDocumentReferenceLinksInAccountStatementInput)"
            )
        } catch {
            let appError = error.toAppError()
            self.minimumCashReserveError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }
        self.isLoading = false
    }

    func resetToDefaults() async {
        guard let configurationService else {
            self.minimumCashReserveError = "Configuration service unavailable"
            return
        }
        self.isLoading = true
        self.minimumCashReserveError = nil
        self.initialAccountBalanceError = nil
        self.poolBalanceDistributionThresholdError = nil
        self.traderCommissionRateError = nil

        do {
            try await configurationService.resetToDefaults()
            self.minimumCashReserveInput = configurationService.minimumCashReserve
            self.initialAccountBalanceInput = configurationService.initialAccountBalance
            self.poolBalanceDistributionStrategy = configurationService.poolBalanceDistributionStrategy
            self.poolBalanceDistributionThresholdInput = configurationService.poolBalanceDistributionThreshold
            self.traderCommissionRateInput = configurationService.traderCommissionRate
            self.showCommissionBreakdownInCreditNoteInput = configurationService.showCommissionBreakdownInCreditNote
            self.showDocumentReferenceLinksInAccountStatementInput = configurationService.showDocumentReferenceLinksInAccountStatement
            print("✅ Configuration reset to defaults")
        } catch {
            let appError = error.toAppError()
            self.minimumCashReserveError = "Failed to reset: \(appError.errorDescription ?? "An error occurred")"
        }

        self.isLoading = false
    }

    func updateUserMinimumCashReserve() async {
        guard let configurationService else {
            self.userMinimumCashReserveError = "Configuration service unavailable"
            return
        }
        guard self.isValidUserMinimumCashReserve else {
            self.userMinimumCashReserveError = "User ID is required and value must be between 0.01 and 1000.0"
            return
        }

        self.isLoading = true
        self.userMinimumCashReserveError = nil

        do {
            try await configurationService.updateMinimumCashReserve(self.userMinimumCashReserveInput, for: self.userMinimumCashReserveUserId)
            print("✅ User \(self.userMinimumCashReserveUserId) minimum cash reserve updated to \(self.userMinimumCashReserveInput)")
            self.userMinimumCashReserveUserId = ""
            self.userMinimumCashReserveInput = configurationService.minimumCashReserve
        } catch {
            let appError = error.toAppError()
            self.userMinimumCashReserveError = "Failed to update: \(appError.errorDescription ?? "An error occurred")"
        }

        self.isLoading = false
    }
}

@available(*, deprecated, renamed: "ConfigurationSettingsViewModel")
typealias ConfigurationManagementViewModel = ConfigurationSettingsViewModel
