import SwiftUI

// MARK: - Configuration Management View
/// Admin interface for managing application configuration settings
struct ConfigurationManagementView: View {
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: ConfigurationManagementViewModel

    init() {
        self._viewModel = StateObject(wrappedValue: ConfigurationManagementViewModel())
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
                // Load current configuration values
                viewModel.minimumCashReserveInput = appServices.configurationService.minimumCashReserve
                viewModel.initialAccountBalanceInput = appServices.configurationService.initialAccountBalance
                viewModel.poolBalanceDistributionStrategy = appServices.configurationService.poolBalanceDistributionStrategy
                viewModel.poolBalanceDistributionThresholdInput = appServices.configurationService.poolBalanceDistributionThreshold
                viewModel.traderCommissionRateInput = appServices.configurationService.traderCommissionRate
            }
        }
        .environmentObject(viewModel)
    }

    // MARK: - Configuration Section
    @ViewBuilder
    private var configurationSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                Text("Account Settings")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(.primary)

                MinimumCashReserveSection(viewModel: viewModel)
                UserMinimumCashReserveSection(viewModel: viewModel)
                InitialAccountBalanceSection(viewModel: viewModel)
                TraderCommissionRateSection(viewModel: viewModel)
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
                .font(.system(size: ResponsiveDesign.iconSize() * 2))
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
    ConfigurationManagementView()
        .environment(\.appServices, AppServices.live)
}
