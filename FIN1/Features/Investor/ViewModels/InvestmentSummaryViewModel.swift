import Foundation
import SwiftUI

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
    let configurationService: any ConfigurationServiceProtocol

    // MARK: - Initialization
    init(
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        totalInvestmentAmount: Double,
        configurationService: any ConfigurationServiceProtocol
    ) {
        self.amountPerInvestment = amountPerInvestment
        self.numberOfInvestments = numberOfInvestments
        self.totalInvestmentAmount = totalInvestmentAmount
        self.configurationService = configurationService
    }

    // MARK: - Update Methods
    func update(amountPerInvestment: Double, numberOfInvestments: Int, totalInvestmentAmount: Double) {
        self.amountPerInvestment = amountPerInvestment
        self.numberOfInvestments = numberOfInvestments
        self.totalInvestmentAmount = totalInvestmentAmount
    }

    // MARK: - Display Properties (Formatted for UI)

    var formattedAmountPerInvestment: String {
        self.amountPerInvestment.formattedAsLocalizedCurrency()
    }

    var formattedTotalInvestment: String {
        self.totalInvestmentAmount.formattedAsLocalizedCurrency()
    }

    var numberOfInvestmentsText: String {
        "\(self.numberOfInvestments)"
    }

    var appServiceCharge: Double {
        self.totalInvestmentAmount * self.configurationService.effectiveAppServiceChargeRate
    }

    var formattedAppServiceCharge: String {
        self.appServiceCharge.formattedAsLocalizedCurrency()
    }

    // MARK: - Error Handling

    func clearError() {
        self.errorMessage = nil
    }

    func showError(_ error: AppError) {
        self.errorMessage = error.errorDescription ?? "An error occurred"
    }
}
