import SwiftUI

// MARK: - Configuration Settings View
/// Admin interface for managing application configuration settings
struct ConfigurationSettingsView: View {
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: ConfigurationSettingsViewModel

    init() {
        self._viewModel = StateObject(wrappedValue: ConfigurationSettingsViewModel())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                if appServices.userService.userRole == .admin {
                    configurationSection
                } else {
                    unauthorizedAccessView
                }
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.large)
            .responsivePadding()
            .onAppear {
                viewModel.configure(with: appServices.configurationService)
            }
        }
        .environmentObject(viewModel)
    }

    // MARK: - Configuration Section
    @ViewBuilder
    private var configurationSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                // 4-Eyes Approval Section
                PendingApprovalsSection()

                Text("Account Settings")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(.primary)

                MinimumCashReserveSection(viewModel: viewModel)
                UserMinimumCashReserveSection(viewModel: viewModel)
                InitialAccountBalanceSection(viewModel: viewModel)
                TraderCommissionRateSection(viewModel: viewModel)
                ShowCommissionBreakdownInCreditNoteSection(viewModel: viewModel)
                ShowDocumentReferenceLinksInAccountStatementSection(viewModel: viewModel)
                PoolBalanceDistributionSection(viewModel: viewModel)
                ResetToDefaultsSection(viewModel: viewModel)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(ResponsiveDesign.spacing(12))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }

    // MARK: - Unauthorized Access View
    @ViewBuilder
    private var unauthorizedAccessView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "lock.shield")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(.red)

            Text("Access Denied")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(.primary)

            Text("You need administrator privileges to access configuration settings.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    ConfigurationSettingsView()
        .environment(\.appServices, AppServices.live)
}

@available(*, deprecated, renamed: "ConfigurationSettingsView")
typealias ConfigurationManagementView = ConfigurationSettingsView
