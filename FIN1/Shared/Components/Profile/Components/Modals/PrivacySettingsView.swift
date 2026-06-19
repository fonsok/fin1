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
                    StripedStepList {
                        self.headerSection
                            .stripedListSection(stripeIndex: 0)

                        self.dataCollectionSection
                            .stripedListSection(stripeIndex: 1)

                        self.dataVisibilitySection
                            .stripedListSection(stripeIndex: 2)

                        self.communicationSection
                            .stripedListSection(stripeIndex: 3)

                        self.dataManagementSection
                            .stripedListSection(stripeIndex: 4)

                        self.quickActionsSection
                            .stripedListSection(stripeIndex: 5)
                    }
                    .padding(.bottom, ResponsiveDesign.spacing(16))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { self.toolbarContent }
            .alert("Data Export", isPresented: self.$viewModel.showDataExportConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Export My Data") { self.viewModel.requestDataExport() }
            } message: {
                Text(
                    "We will prepare a complete copy of your personal data. You will receive an email with a download link within 72 hours."
                )
            }
            .alert("Delete My Data", isPresented: self.$viewModel.showDataDeletionConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Request Deletion", role: .destructive) { self.viewModel.requestDataDeletion() }
            } message: {
                Text(
                    "This will submit a request to permanently delete your personal data. This action cannot be undone. Your account will be deactivated after processing."
                )
            }
            .alert("Success", isPresented: self.$viewModel.showSuccessMessage) {
                Button("OK") {}
            } message: {
                Text(self.viewModel.successMessage)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { self.dismiss() }
                .foregroundColor(AppTheme.fontColor)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                self.viewModel.saveSettings()
                self.dismiss()
            }
            .foregroundColor(AppTheme.accentLightBlue)
            .fontWeight(.semibold)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "hand.raised.fill")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.accentGreen)
            Text("Privacy Settings")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.center)
            Text("Control how your data is collected and used")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Data Collection Section

    private var dataCollectionSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            ProfileIconSectionTitle(
                title: "Data Collection",
                icon: "chart.bar.doc.horizontal.fill",
                color: AppTheme.accentLightBlue
            )
            ProfileSectionDivider()
            self.privacyToggle(
                self.$viewModel.analyticsEnabled,
                title: "Analytics",
                subtitle: "Help improve the app by sharing usage statistics"
            )
            ProfileSectionDivider()
            self.privacyToggle(
                self.$viewModel.crashReportingEnabled,
                title: "Crash Reporting",
                subtitle: "Automatically send crash reports to help fix issues"
            )
            ProfileSectionDivider()
            self.privacyToggle(
                self.$viewModel.usageDataSharingEnabled,
                title: "Usage Data Sharing",
                subtitle: "Share anonymous usage data with our partners"
            )
            ProfileSectionDivider()
            self.privacyToggle(
                self.$viewModel.personalizedAdsEnabled,
                title: "Personalized Ads",
                subtitle: "Show ads based on your interests and activity"
            )
        }
    }

    // MARK: - Data Visibility Section

    private var dataVisibilitySection: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            ProfileIconSectionTitle(title: "Data Visibility", icon: "eye.fill", color: AppTheme.accentOrange)
            ProfileSectionDivider()
            self.privacyToggle(
                self.$viewModel.profileVisibleToTraders,
                title: "Profile Visible to Traders",
                subtitle: "Allow traders to see your investor profile"
            )
            ProfileSectionDivider()
            self.privacyToggle(
                self.$viewModel.investmentHistoryVisible,
                title: "Investment History",
                subtitle: "Show your investment history to connected traders"
            )
            ProfileSectionDivider()
            self.privacyToggle(
                self.$viewModel.performanceMetricsVisible,
                title: "Performance Metrics",
                subtitle: "Display your investment performance publicly"
            )
        }
    }

    // MARK: - Communication Section

    private var communicationSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            ProfileIconSectionTitle(title: "Communication Preferences", icon: "envelope.fill", color: AppTheme.accentGreen)
            ProfileSectionDivider()
            self.privacyToggle(
                self.$viewModel.marketingEmailsEnabled,
                title: "Marketing Emails",
                subtitle: "Receive promotional emails and offers"
            )
            ProfileSectionDivider()
            self.privacyToggle(
                self.$viewModel.thirdPartyDataSharingEnabled,
                title: "Third-Party Data Sharing",
                subtitle: "Allow sharing data with trusted partners"
            )
            ProfileSectionDivider()
            self.privacyToggle(
                self.$viewModel.newsletterSubscribed,
                title: "Newsletter",
                subtitle: "Receive our weekly investment newsletter"
            )
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            ProfileIconSectionTitle(title: "Your Data Rights", icon: "doc.text.fill", color: AppTheme.accentRed)
            ProfileSectionDivider()
            self.dataActionRow(
                icon: "square.and.arrow.up.fill",
                title: "Export My Data",
                color: AppTheme.accentLightBlue,
                isLoading: self.viewModel.isExportingData
            ) {
                self.viewModel.showDataExportConfirmation = true
            }
            ProfileSectionDivider()
            self.dataActionRow(
                icon: "trash.fill",
                title: "Delete My Data",
                color: AppTheme.accentRed,
                isLoading: self.viewModel.isDeletingData
            ) {
                self.viewModel.showDataDeletionConfirmation = true
            }
            ProfileSectionDivider()
            Text("Under GDPR and CCPA, you have the right to access, export, and delete your personal data.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, ResponsiveDesign.spacing(12))
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        Button(action: { self.viewModel.resetToDefaults() }) {
            HStack {
                Image(systemName: "arrow.clockwise").font(ResponsiveDesign.bodyFont())
                Text("Reset to Defaults").font(ResponsiveDesign.bodyFont()).fontWeight(.medium)
                Spacer()
            }
            .foregroundColor(AppTheme.accentLightBlue)
            .padding(.vertical, ResponsiveDesign.spacing(4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func privacyToggle(_ binding: Binding<Bool>, title: String, subtitle: String) -> some View {
        SettingsToggleRow(
            title: title,
            subtitle: subtitle,
            isEnabled: binding,
            tintColor: AppTheme.accentGreen
        )
        .padding(.vertical, ResponsiveDesign.spacing(12))
    }

    private func dataActionRow(
        icon: String,
        title: String,
        color: Color,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).font(ResponsiveDesign.bodyFont())
                Text(title).font(ResponsiveDesign.bodyFont()).fontWeight(.medium)
                Spacer(minLength: 0)
                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right").font(ResponsiveDesign.captionFont())
                }
            }
            .foregroundColor(color)
            .padding(.vertical, ResponsiveDesign.spacing(12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    PrivacySettingsView()
        .environment(\.appServices, AppServices.live)
}
