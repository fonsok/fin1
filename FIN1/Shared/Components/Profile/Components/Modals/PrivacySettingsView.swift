import SwiftUI

// MARK: - Privacy Settings View
/// User interface for managing privacy settings and data control preferences
/// Implements GDPR and CCPA compliant privacy controls
struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: PrivacySettingsViewModel

    init() {
        let services = AppServices.live
        _viewModel = StateObject(wrappedValue: PrivacySettingsViewModel(
            userService: services.userService
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(24)) {
                        headerSection
                        dataCollectionSection
                        dataVisibilitySection
                        communicationSection
                        dataManagementSection
                        quickActionsSection
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.bottom, ResponsiveDesign.spacing(16))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Data Export", isPresented: $viewModel.showDataExportConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Export My Data") { viewModel.requestDataExport() }
            } message: {
                Text("We will prepare a complete copy of your personal data. You will receive an email with a download link within 72 hours.")
            }
            .alert("Delete My Data", isPresented: $viewModel.showDataDeletionConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Request Deletion", role: .destructive) { viewModel.requestDataDeletion() }
            } message: {
                Text("This will submit a request to permanently delete your personal data. This action cannot be undone. Your account will be deactivated after processing.")
            }
            .alert("Success", isPresented: $viewModel.showSuccessMessage) {
                Button("OK") {}
            } message: {
                Text(viewModel.successMessage)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
                .foregroundColor(AppTheme.fontColor)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                viewModel.saveSettings()
                dismiss()
            }
            .foregroundColor(AppTheme.accentLightBlue)
            .fontWeight(.semibold)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.accentGreen)
            Text("Privacy Settings")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
            Text("Control how your data is collected and used")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, ResponsiveDesign.spacing(16))
    }

    // MARK: - Data Collection Section

    private var dataCollectionSection: some View {
        privacySection(title: "Data Collection", icon: "chart.bar.doc.horizontal.fill", color: AppTheme.accentLightBlue) {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                SettingsToggleRow(title: "Analytics", subtitle: "Help improve the app by sharing usage statistics", isEnabled: $viewModel.analyticsEnabled, tintColor: AppTheme.accentGreen)
                SettingsToggleRow(title: "Crash Reporting", subtitle: "Automatically send crash reports to help fix issues", isEnabled: $viewModel.crashReportingEnabled, tintColor: AppTheme.accentGreen)
                SettingsToggleRow(title: "Usage Data Sharing", subtitle: "Share anonymous usage data with our partners", isEnabled: $viewModel.usageDataSharingEnabled, tintColor: AppTheme.accentGreen)
                SettingsToggleRow(title: "Personalized Ads", subtitle: "Show ads based on your interests and activity", isEnabled: $viewModel.personalizedAdsEnabled, tintColor: AppTheme.accentGreen)
            }
        }
    }

    // MARK: - Data Visibility Section

    private var dataVisibilitySection: some View {
        privacySection(title: "Data Visibility", icon: "eye.fill", color: AppTheme.accentOrange) {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                SettingsToggleRow(title: "Profile Visible to Traders", subtitle: "Allow traders to see your investor profile", isEnabled: $viewModel.profileVisibleToTraders, tintColor: AppTheme.accentGreen)
                SettingsToggleRow(title: "Investment History", subtitle: "Show your investment history to connected traders", isEnabled: $viewModel.investmentHistoryVisible, tintColor: AppTheme.accentGreen)
                SettingsToggleRow(title: "Performance Metrics", subtitle: "Display your investment performance publicly", isEnabled: $viewModel.performanceMetricsVisible, tintColor: AppTheme.accentGreen)
            }
        }
    }

    // MARK: - Communication Section

    private var communicationSection: some View {
        privacySection(title: "Communication Preferences", icon: "envelope.fill", color: AppTheme.accentGreen) {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                SettingsToggleRow(title: "Marketing Emails", subtitle: "Receive promotional emails and offers", isEnabled: $viewModel.marketingEmailsEnabled, tintColor: AppTheme.accentGreen)
                SettingsToggleRow(title: "Third-Party Data Sharing", subtitle: "Allow sharing data with trusted partners", isEnabled: $viewModel.thirdPartyDataSharingEnabled, tintColor: AppTheme.accentGreen)
                SettingsToggleRow(title: "Newsletter", subtitle: "Receive our weekly investment newsletter", isEnabled: $viewModel.newsletterSubscribed, tintColor: AppTheme.accentGreen)
            }
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        privacySection(title: "Your Data Rights", icon: "doc.text.fill", color: AppTheme.accentRed) {
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                dataActionButton(icon: "square.and.arrow.up.fill", title: "Export My Data", color: AppTheme.accentLightBlue, isLoading: viewModel.isExportingData) {
                    viewModel.showDataExportConfirmation = true
                }
                dataActionButton(icon: "trash.fill", title: "Delete My Data", color: AppTheme.accentRed, isLoading: viewModel.isDeletingData) {
                    viewModel.showDataDeletionConfirmation = true
                }
                Text("Under GDPR and CCPA, you have the right to access, export, and delete your personal data.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.top, ResponsiveDesign.spacing(8))
            }
        }
    }

    private func dataActionButton(icon: String, title: String, color: Color, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).font(ResponsiveDesign.bodyFont())
                Text(title).font(ResponsiveDesign.bodyFont()).fontWeight(.medium)
                Spacer()
                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right").font(ResponsiveDesign.captionFont())
                }
            }
            .foregroundColor(color)
            .padding(ResponsiveDesign.spacing(12))
            .background(AppTheme.systemTertiaryBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .disabled(isLoading)
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        Button(action: { viewModel.resetToDefaults() }) {
            HStack {
                Image(systemName: "arrow.clockwise").font(ResponsiveDesign.bodyFont())
                Text("Reset to Defaults").font(ResponsiveDesign.bodyFont()).fontWeight(.medium)
            }
            .foregroundColor(AppTheme.accentLightBlue)
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }

    // MARK: - Helper Methods

    private func privacySection<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Image(systemName: icon).font(ResponsiveDesign.headlineFont()).foregroundColor(color).frame(width: 24)
                Text(title).font(ResponsiveDesign.headlineFont()).foregroundColor(AppTheme.fontColor)
                Spacer()
            }
            content()
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Preview

#Preview {
    PrivacySettingsView()
        .environment(\.appServices, AppServices.live)
}
