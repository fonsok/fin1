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
        self.tradingFeePercentage = UserDefaults.standard.object(forKey: "tradingFeePercentage") as? Double ?? 0.0025
        self.managementFeePercentage = UserDefaults.standard.object(forKey: "managementFeePercentage") as? Double ?? 0.02
        self.performanceFeePercentage = UserDefaults.standard.object(forKey: "performanceFeePercentage") as? Double ?? 0.20
        self.minimumInvestmentAmount = UserDefaults.standard.object(forKey: "minimumInvestmentAmount") as? Double ?? 50.0
        self.maximumInvestmentAmount = UserDefaults.standard.object(forKey: "maximumInvestmentAmount") as? Double ?? 1_000_000.0
        self.hasUnsavedChanges = false
    }

    func markAsChanged() {
        self.hasUnsavedChanges = true
    }

    func saveChanges() async {
        self.isSaving = true
        defer { isSaving = false }

        // Simulate API/network work while keeping View layer passive.
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        UserDefaults.standard.set(self.tradingFeePercentage, forKey: "tradingFeePercentage")
        UserDefaults.standard.set(self.managementFeePercentage, forKey: "managementFeePercentage")
        UserDefaults.standard.set(self.performanceFeePercentage, forKey: "performanceFeePercentage")
        UserDefaults.standard.set(self.minimumInvestmentAmount, forKey: "minimumInvestmentAmount")
        UserDefaults.standard.set(self.maximumInvestmentAmount, forKey: "maximumInvestmentAmount")

        self.hasUnsavedChanges = false
        self.showSaveSuccess = true
    }
}
