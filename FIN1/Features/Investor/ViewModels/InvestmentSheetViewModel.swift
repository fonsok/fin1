import SwiftUI
import Foundation

// MARK: - Investment Sheet View Model
/// ViewModel for InvestmentSheet following MVVM architecture
/// Handles all business logic, calculations, validation, and state management
@MainActor
final class InvestmentSheetViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var investmentAmount: String = String(
        Int(CalculationConstants.Investment.defaultAmount)
    )
    @Published var selectedInvestmentSelection: InvestmentSelectionStrategy = .multipleInvestments
    @Published var numberOfInvestments: Int = 3
    @Published var showInvestmentError = false
    @Published var investmentErrorMessage = ""
    @Published var showSuccess = false
    @Published var isLoading = false
    @Published var isCommissionConfirmed = false

    // MARK: - Dependencies
    private let trader: MockTrader
    private let userService: any UserServiceProtocol
    private let investmentService: any InvestmentServiceProtocol
    private let telemetryService: any TelemetryServiceProtocol
    private let investorCashBalanceService: any InvestorCashBalanceServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol
    private let onInvestmentSuccess: (() -> Void)?

    // MARK: - Initialization
    init(
        trader: MockTrader,
        userService: any UserServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        telemetryService: any TelemetryServiceProtocol,
        investorCashBalanceService: any InvestorCashBalanceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        onInvestmentSuccess: (() -> Void)? = nil
    ) {
        self.trader = trader
        self.userService = userService
        self.investmentService = investmentService
        self.telemetryService = telemetryService
        self.investorCashBalanceService = investorCashBalanceService
        self.configurationService = configurationService
        self.onInvestmentSuccess = onInvestmentSuccess
    }

    // MARK: - Computed Properties (Business Logic)

    var currentUser: User? {
        userService.currentUser
    }

    var amountPerInvestment: Double {
        let totalAmount = Double(investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0
        return totalAmount > 0 ? totalAmount / Double(numberOfInvestments) : 0
    }

    var totalInvestmentAmount: Double {
        Double(investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0
    }

    /// Calculates the app service charge for the current investment amount
    /// - Note: Service charge applies ONLY to investors (not traders)
    var appServiceCharge: Double {
        totalInvestmentAmount * configurationService.effectiveAppServiceChargeRate
    }

    /// Total amount required (investment + app service charge)
    var totalRequiredAmount: Double {
        totalInvestmentAmount + appServiceCharge
    }

    /// Validates that cash balance after investment + fee will be >= minimum cash reserve
    var hasSufficientCashBalance: Bool {
        guard let currentUser = currentUser else { return false }
        let currentBalance = investorCashBalanceService.getBalance(for: currentUser.id)
        let remainingBalance = currentBalance - totalRequiredAmount
        let minimumReserve = configurationService.getMinimumCashReserve(for: currentUser.id)
        return remainingBalance >= minimumReserve
    }

    /// Shows warning when cash balance is insufficient
    var showInsufficientCashBalanceWarning: Bool {
        guard !investmentAmount.isEmpty,
              Double(investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0 > 0 else {
            return false
        }
        return !hasSufficientCashBalance
    }

    /// Message explaining insufficient cash balance
    var insufficientCashBalanceMessage: String {
        guard let currentUser = currentUser else {
            return "Please log in to check your balance."
        }
        let currentBalance = investorCashBalanceService.getBalance(for: currentUser.id)
        let remainingBalance = currentBalance - totalRequiredAmount
        let minimumRequired = configurationService.getMinimumCashReserve(for: currentUser.id)
        let shortfall = max(0, minimumRequired - remainingBalance)

        return "Insufficient funds. Current balance: \(currentBalance.formattedAsLocalizedCurrency()), Estimated after investment: \(remainingBalance.formattedAsLocalizedCurrency()). Need \(shortfall.formattedAsLocalizedCurrency()) more to maintain minimum reserve of \(minimumRequired.formattedAsLocalizedCurrency())."
    }

    /// Current cash balance for the investor
    var currentCashBalance: Double {
        guard let currentUser = currentUser else { return 0 }
        return investorCashBalanceService.getBalance(for: currentUser.id)
    }

    /// Remaining balance after investment and fee
    var remainingBalanceAfterInvestment: Double {
        guard let currentUser = currentUser else { return 0 }
        let currentBalance = investorCashBalanceService.getBalance(for: currentUser.id)
        return currentBalance - totalRequiredAmount
    }

    var canProceed: Bool {
        let total = Double(investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0
        let perSlot = amountPerInvestment
        let minSlot = configurationService.minimumInvestmentAmount
        let maxSlot = configurationService.maximumInvestmentAmount
        let withinSlotLimits = total > 0 && perSlot >= minSlot && perSlot <= maxSlot
        return !investmentAmount.isEmpty &&
        total > 0 &&
        withinSlotLimits &&
        numberOfInvestments >= 1 &&
        numberOfInvestments <= 10 &&
        hasSufficientCashBalance &&
        isCommissionConfirmed
    }

    /// Positive total entered, slot count valid, but amount per slot violates admin min/max (so „Invest“ stays disabled).
    var showInvestmentSlotLimitHint: Bool {
        let total = totalInvestmentAmount
        guard total > 0,
              numberOfInvestments >= 1,
              numberOfInvestments <= 10 else { return false }
        let per = amountPerInvestment
        let minSlot = configurationService.minimumInvestmentAmount
        let maxSlot = configurationService.maximumInvestmentAmount
        return per < minSlot || per > maxSlot
    }

    var investmentSlotLimitHintMessage: String {
        let per = amountPerInvestment
        let minSlot = configurationService.minimumInvestmentAmount
        let maxSlot = configurationService.maximumInvestmentAmount
        let perFormatted = per.formattedAsLocalizedCurrency()
        if per < minSlot {
            return
                "Der Betrag je Anlageposition beträgt \(perFormatted), erlaubt sind mindestens \(minSlot.formattedAsLocalizedCurrency()). " +
                "Erhöhen Sie den Gesamtbetrag oder reduzieren Sie die Anzahl der Anlagen."
        }
        if per > maxSlot {
            return
                "Der Betrag je Anlageposition beträgt \(perFormatted), erlaubt sind höchstens \(maxSlot.formattedAsLocalizedCurrency()). " +
                "Erhöhen Sie die Anzahl der Anlagen oder senken Sie den Gesamtbetrag."
        }
        return ""
    }

    // MARK: - Server-aligned limits (best practices: refresh getConfig before investing)

    /// Pulls latest `getConfig` limits/fees, then caps the total amount field to the configured maximum.
    func prepareForInvestingFlow() async {
        await configurationService.refreshConfigurationFromServerIfAvailable()
        applyConfiguredMaximumToAmountField()
    }

    /// Caps `investmentAmount` (whole euros) to `maximumInvestmentAmount` after a config refresh.
    func applyConfiguredMaximumToAmountField() {
        let maxEuros = max(0, Int(floor(configurationService.maximumInvestmentAmount)))
        guard maxEuros > 0 else { return }
        let raw = Int(investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0
        if raw > maxEuros {
            investmentAmount = String(maxEuros)
        }
    }

    // MARK: - Validation

    func validateUserCanInvest() -> Bool {
        guard let currentUser = currentUser else {
            showInvestmentError("Please log in to make investments")
            return false
        }

        if currentUser.role == .trader {
            showInvestmentError("Traders cannot invest in other traders")
            return false
        }

        return true
    }

    // MARK: - Investment Creation

    func createInvestment() async {
        guard validateUserCanInvest() else { return }
        guard let currentUser = currentUser else { return }

        isLoading = true
        await prepareForInvestingFlow()

        guard canProceed else {
            isLoading = false
            return
        }

        let amountPerInvestment = self.amountPerInvestment

        Task {
            do {
                // Create the investment using the current user and trader data
                try await investmentService.createInvestment(
                    investor: currentUser,
                    trader: trader,
                    amountPerInvestment: amountPerInvestment,
                    numberOfInvestments: numberOfInvestments,
                    specialization: trader.specialization,
                    potSelection: selectedInvestmentSelection
                )

                await MainActor.run {
                    self.isLoading = false
                    // Show success message briefly, then dismiss and return to investor dashboard
                    self.showSuccess = true
                    // Dismiss the sheet after a short delay to show the success message
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                        await MainActor.run {
                            self.onInvestmentSuccess?()
                        }
                    }
                }
            } catch let error as AppError {
                await MainActor.run {
                    self.isLoading = false
                    self.showInvestmentError(error.userFacingInvestmentMessage)

                    // Track error with investment context
                    let context = ErrorContext(
                        screen: "InvestmentSheet",
                        action: "createInvestment",
                        userId: currentUser.id,
                        userRole: currentUser.role.displayName,
                        additionalData: [
                            "trader_id": trader.id.uuidString,
                            "trader_name": trader.name,
                            "investment_amount": amountPerInvestment,
                            "number_of_investments": numberOfInvestments,
                            "specialization": trader.specialization,
                            "investment_selection": selectedInvestmentSelection.rawValue
                        ]
                    )
                    telemetryService.trackAppError(error, context: context)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    let appError = error.toAppError()
                    self.showInvestmentError(appError.userFacingInvestmentMessage)

                    // Track unknown error
                    let context = ErrorContext(
                        screen: "InvestmentSheet",
                        action: "createInvestment",
                        userId: currentUser.id,
                        userRole: currentUser.role.displayName,
                        additionalData: [
                            "original_error": appError.errorDescription ?? "unknown",
                            "trader_id": trader.id.uuidString,
                            "investment_amount": amountPerInvestment
                        ]
                    )
                    telemetryService.trackAppError(appError, context: context)
                }
            }
        }
    }

    // MARK: - Error Handling

    private func showInvestmentError(_ message: String) {
        investmentErrorMessage = message
        showInvestmentError = true
    }
}
