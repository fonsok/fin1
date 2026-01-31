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

    // MARK: - Initialization
    init(updateInvestmentAmount: @escaping (String) -> Void, getInvestmentAmount: @escaping () -> String) {
        self.updateInvestmentAmount = updateInvestmentAmount
        self.getInvestmentAmount = getInvestmentAmount
    }

    // MARK: - Input Formatting Methods

    /// Formats and validates input, updating both display and backing amount
    func formatAndValidateInput(_ newValue: String) {
        // Remove any non-numeric characters except dots (for German formatting)
        let cleanedInput = newValue.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)

        // If empty, clear both display and amount
        if cleanedInput.isEmpty {
            displayAmount = ""
            updateInvestmentAmount("")
            return
        }

        // Remove dots and convert to integer
        let numericString = cleanedInput.replacingOccurrences(of: ".", with: "")

        // Validate that it's a valid integer
        guard let integerValue = Int(numericString), integerValue >= 0 else {
            // If invalid, revert to previous valid state
            updateDisplayFromAmount()
            return
        }

        // Format with localized thousand separators
        let formattedString = integerValue.formattedAsLocalizedInteger()

        // Update both display and backing amount
        displayAmount = formattedString
        updateInvestmentAmount(numericString)
    }

    /// Updates the display amount from the backing investment amount
    func updateDisplayFromAmount() {
        let investmentAmount = getInvestmentAmount()
        guard let integerValue = Int(investmentAmount), integerValue >= 0 else {
            displayAmount = ""
            return
        }
        displayAmount = integerValue.formattedAsLocalizedInteger()
    }

    // MARK: - Platform Service Charge Calculation

    /// Calculates the platform service charge for the current investment amount
    /// - Note: Currently applies to investors when creating investments (not traders).
    ///   Can be extended to traders in the future if needed.
    var platformServiceCharge: Double {
        let investmentAmount = getInvestmentAmount()
        let amountValue = Double(investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0
        return amountValue * CalculationConstants.ServiceCharges.platformServiceChargeRate
    }

    /// Formatted platform service charge for display
    var formattedPlatformServiceCharge: String {
        platformServiceCharge.formattedAsLocalizedCurrency()
    }

    /// Whether the investment amount is greater than zero
    var hasValidAmount: Bool {
        let investmentAmount = getInvestmentAmount()
        let amountValue = Double(investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0
        return amountValue > 0
    }
}
