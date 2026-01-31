import Foundation
import Combine

// MARK: - Privacy Settings ViewModel
/// ViewModel for managing user privacy settings and data control preferences
final class PrivacySettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    // Data Collection Preferences
    @Published var analyticsEnabled: Bool = true
    @Published var crashReportingEnabled: Bool = true
    @Published var usageDataSharingEnabled: Bool = false
    @Published var personalizedAdsEnabled: Bool = false

    // Data Visibility
    @Published var profileVisibleToTraders: Bool = true
    @Published var investmentHistoryVisible: Bool = false
    @Published var performanceMetricsVisible: Bool = true

    // Communication Preferences
    @Published var marketingEmailsEnabled: Bool = false
    @Published var thirdPartyDataSharingEnabled: Bool = false
    @Published var newsletterSubscribed: Bool = true

    // Data Management
    @Published var showDataExportConfirmation: Bool = false
    @Published var showDataDeletionConfirmation: Bool = false
    @Published var isExportingData: Bool = false
    @Published var isDeletingData: Bool = false
    @Published var showSuccessMessage: Bool = false
    @Published var successMessage: String = ""

    // MARK: - Private Properties

    private let userService: any UserServiceProtocol
    private let userDefaultsKey = "FIN1_PrivacySettings"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(userService: any UserServiceProtocol) {
        self.userService = userService
        loadSettings()
    }

    // MARK: - Public Methods

    /// Saves all privacy settings to persistent storage
    func saveSettings() {
        let settings = PrivacySettings(
            analyticsEnabled: analyticsEnabled,
            crashReportingEnabled: crashReportingEnabled,
            usageDataSharingEnabled: usageDataSharingEnabled,
            personalizedAdsEnabled: personalizedAdsEnabled,
            profileVisibleToTraders: profileVisibleToTraders,
            investmentHistoryVisible: investmentHistoryVisible,
            performanceMetricsVisible: performanceMetricsVisible,
            marketingEmailsEnabled: marketingEmailsEnabled,
            thirdPartyDataSharingEnabled: thirdPartyDataSharingEnabled,
            newsletterSubscribed: newsletterSubscribed
        )

        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    /// Resets all privacy settings to default values
    func resetToDefaults() {
        analyticsEnabled = true
        crashReportingEnabled = true
        usageDataSharingEnabled = false
        personalizedAdsEnabled = false
        profileVisibleToTraders = true
        investmentHistoryVisible = false
        performanceMetricsVisible = true
        marketingEmailsEnabled = false
        thirdPartyDataSharingEnabled = false
        newsletterSubscribed = true
    }

    /// Requests data export (GDPR Article 20 - Right to data portability)
    func requestDataExport() {
        isExportingData = true
        Task { @MainActor [weak self] in
            // Simulate export process
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.isExportingData = false
            self?.successMessage = "Your data export has been initiated. You will receive an email with your data within 72 hours."
            self?.showSuccessMessage = true
        }
    }

    /// Requests account data deletion (GDPR Article 17 - Right to erasure)
    func requestDataDeletion() {
        isDeletingData = true
        Task { @MainActor [weak self] in
            // Simulate deletion request
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.isDeletingData = false
            self?.successMessage = "Your data deletion request has been submitted. We will process it within 30 days as required by law."
            self?.showSuccessMessage = true
        }
    }

    // MARK: - Private Methods

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(PrivacySettings.self, from: data) else {
            return
        }

        analyticsEnabled = settings.analyticsEnabled
        crashReportingEnabled = settings.crashReportingEnabled
        usageDataSharingEnabled = settings.usageDataSharingEnabled
        personalizedAdsEnabled = settings.personalizedAdsEnabled
        profileVisibleToTraders = settings.profileVisibleToTraders
        investmentHistoryVisible = settings.investmentHistoryVisible
        performanceMetricsVisible = settings.performanceMetricsVisible
        marketingEmailsEnabled = settings.marketingEmailsEnabled
        thirdPartyDataSharingEnabled = settings.thirdPartyDataSharingEnabled
        newsletterSubscribed = settings.newsletterSubscribed
    }
}
