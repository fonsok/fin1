import Foundation

// MARK: - Investment Form View Model
/// ViewModel for InvestmentFormView to handle input formatting logic
@MainActor
final class InvestmentFormViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var displayAmount: String = ""

    // MARK: - Dependencies
    private var updateInvestmentAmount: (String) -> Void
    private var getInvestmentAmount: () -> String
    let configurationService: any ConfigurationServiceProtocol
    /// Prevents `updateDisplayFromAmount` from fighting with in-flight `formatAndValidateInput`.
    private var lastEmittedBackingAmount: String = ""

    // MARK: - Initialization
    init(
        updateInvestmentAmount: @escaping (String) -> Void,
        getInvestmentAmount: @escaping () -> String,
        configurationService: any ConfigurationServiceProtocol
    ) {
        self.updateInvestmentAmount = updateInvestmentAmount
        self.getInvestmentAmount = getInvestmentAmount
        self.configurationService = configurationService
    }

    // MARK: - Input Formatting Methods

    /// Whole-euro cap for the **total** in „Investment Amount“ (matches admin `maximumInvestmentAmount`).
    private var maxTotalInvestmentWholeEuros: Int {
        let cap = self.configurationService.maximumInvestmentAmount
        guard cap.isFinite, cap > 0 else {
            return Int(CalculationConstants.Investment.fallbackMaximumInvestmentAmount)
        }
        return max(0, Int(floor(cap)))
    }

    /// Formats and validates input, updating both display and backing amount
    func formatAndValidateInput(_ newValue: String) {
        // Remove any non-numeric characters except dots (for German formatting)
        let cleanedInput = newValue.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)

        // If empty, clear both display and amount
        if cleanedInput.isEmpty {
            if self.displayAmount.isEmpty, self.getInvestmentAmount().isEmpty { return }
            self.lastEmittedBackingAmount = ""
            self.displayAmount = ""
            self.updateInvestmentAmount("")
            return
        }

        // Remove dots and convert to integer
        let numericString = cleanedInput.replacingOccurrences(of: ".", with: "")

        // Validate that it's a valid integer
        guard let integerValue = Int(numericString), integerValue >= 0 else {
            // If invalid, revert to previous valid state
            self.updateDisplayFromAmount()
            return
        }

        let maxEuros = self.maxTotalInvestmentWholeEuros
        let capped = min(integerValue, maxEuros)
        let cappedString = String(capped)

        // Format with localized thousand separators
        let formattedString = capped.formattedAsLocalizedInteger()

        // Avoid re-assigning identical values (prevents TextField cursor jumps + onChange storms).
        if formattedString == self.displayAmount, cappedString == self.getInvestmentAmount() {
            return
        }

        self.lastEmittedBackingAmount = cappedString
        self.displayAmount = formattedString
        if cappedString != self.getInvestmentAmount() {
            self.updateInvestmentAmount(cappedString)
        }
    }

    /// Updates the display amount from the backing investment amount
    func updateDisplayFromAmount() {
        let investmentAmount = self.getInvestmentAmount()
        if investmentAmount == self.lastEmittedBackingAmount, !self.displayAmount.isEmpty {
            return
        }
        guard let integerValue = Int(investmentAmount), integerValue >= 0 else {
            if self.displayAmount.isEmpty { return }
            self.displayAmount = ""
            self.lastEmittedBackingAmount = ""
            return
        }
        let maxEuros = self.maxTotalInvestmentWholeEuros
        let capped = min(integerValue, maxEuros)
        let cappedString = String(capped)
        if capped != integerValue {
            self.lastEmittedBackingAmount = cappedString
            self.updateInvestmentAmount(cappedString)
        } else {
            self.lastEmittedBackingAmount = cappedString
        }
        let formatted = capped.formattedAsLocalizedInteger()
        if formatted != self.displayAmount {
            self.displayAmount = formatted
        }
    }

    // MARK: - App Service Charge Calculation

    /// Calculates the app service charge for the current investment amount
    /// - Note: Currently applies to investors when creating investments (not traders).
    ///   Can be extended to traders in the future if needed.
    var appServiceCharge: Double {
        let investmentAmount = self.getInvestmentAmount()
        let amountValue = Double(investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0
        return amountValue * self.configurationService.effectiveAppServiceChargeRate
    }

    /// Formatted app service charge for display
    var formattedAppServiceCharge: String {
        self.appServiceCharge.formattedAsLocalizedCurrency()
    }

    /// Whether the investment amount is greater than zero
    var hasValidAmount: Bool {
        let investmentAmount = self.getInvestmentAmount()
        let amountValue = Double(investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0
        return amountValue > 0
    }
}
