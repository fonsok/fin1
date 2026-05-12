import Foundation

@MainActor
final class AdminFinancialSettingsViewModel: ObservableObject {
    @Published var tradingFeePercentage: Double = 0.0025
    @Published var managementFeePercentage: Double = 0.02
    @Published var performanceFeePercentage: Double = 0.20
    @Published var minimumInvestmentAmount: Double = 50.0
    @Published var maximumInvestmentAmount: Double = 1_000_000.0

    @Published var hasUnsavedChanges = false
    @Published var isSaving = false
    @Published var showSaveSuccess = false

    func loadCurrentSettings() {
        tradingFeePercentage = UserDefaults.standard.object(forKey: "tradingFeePercentage") as? Double ?? 0.0025
        managementFeePercentage = UserDefaults.standard.object(forKey: "managementFeePercentage") as? Double ?? 0.02
        performanceFeePercentage = UserDefaults.standard.object(forKey: "performanceFeePercentage") as? Double ?? 0.20
        minimumInvestmentAmount = UserDefaults.standard.object(forKey: "minimumInvestmentAmount") as? Double ?? 50.0
        maximumInvestmentAmount = UserDefaults.standard.object(forKey: "maximumInvestmentAmount") as? Double ?? 1_000_000.0
        hasUnsavedChanges = false
    }

    func markAsChanged() {
        hasUnsavedChanges = true
    }

    func saveChanges() async {
        isSaving = true
        defer { isSaving = false }

        // Simulate API/network work while keeping View layer passive.
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        UserDefaults.standard.set(tradingFeePercentage, forKey: "tradingFeePercentage")
        UserDefaults.standard.set(managementFeePercentage, forKey: "managementFeePercentage")
        UserDefaults.standard.set(performanceFeePercentage, forKey: "performanceFeePercentage")
        UserDefaults.standard.set(minimumInvestmentAmount, forKey: "minimumInvestmentAmount")
        UserDefaults.standard.set(maximumInvestmentAmount, forKey: "maximumInvestmentAmount")

        hasUnsavedChanges = false
        showSaveSuccess = true
    }
}
