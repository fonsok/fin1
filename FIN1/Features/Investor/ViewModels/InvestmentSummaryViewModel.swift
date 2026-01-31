import SwiftUI
import Foundation

// MARK: - Investment Summary View Model
/// ViewModel for InvestmentSummaryView following MVVM architecture
@MainActor
final class InvestmentSummaryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    @Published var amountPerInvestment: Double
    @Published var numberOfInvestments: Int
    @Published var totalInvestmentAmount: Double

    // MARK: - Initialization
    init(amountPerInvestment: Double, numberOfInvestments: Int, totalInvestmentAmount: Double) {
        self.amountPerInvestment = amountPerInvestment
        self.numberOfInvestments = numberOfInvestments
        self.totalInvestmentAmount = totalInvestmentAmount
    }

    // MARK: - Update Methods
    func update(amountPerInvestment: Double, numberOfInvestments: Int, totalInvestmentAmount: Double) {
        self.amountPerInvestment = amountPerInvestment
        self.numberOfInvestments = numberOfInvestments
        self.totalInvestmentAmount = totalInvestmentAmount
    }

    // MARK: - Display Properties (Formatted for UI)

    var formattedAmountPerInvestment: String {
        amountPerInvestment.formattedAsLocalizedCurrency()
    }

    var formattedTotalInvestment: String {
        totalInvestmentAmount.formattedAsLocalizedCurrency()
    }

    var numberOfInvestmentsText: String {
        "\(numberOfInvestments)"
    }

    var platformServiceCharge: Double {
        totalInvestmentAmount * CalculationConstants.ServiceCharges.platformServiceChargeRate
    }

    var formattedPlatformServiceCharge: String {
        platformServiceCharge.formattedAsLocalizedCurrency()
    }

    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
    }

    func showError(_ error: AppError) {
        errorMessage = error.errorDescription ?? "An error occurred"
    }
}
