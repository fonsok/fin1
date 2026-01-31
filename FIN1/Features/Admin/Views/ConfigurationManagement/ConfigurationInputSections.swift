import SwiftUI

// MARK: - Configuration Input Sections

/// Reusable component for configuration input fields
struct ConfigurationInputSection: View {
    let title: String
    let description: String
    let currentValue: String
    let inputValue: Binding<Double>
    let isValid: Bool
    let errorMessage: String?
    let updateAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text(title)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.primary)

                Spacer()

                Text(currentValue)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.secondary)
            }

            Text(description)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)

            HStack {
                TextField("Enter amount", value: inputValue, format: .currency(code: "EUR"))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)

                Button("Update") {
                    updateAction()
                }
                .disabled(!isValid)
                .buttonStyle(.borderedProminent)
            }

            if let error = errorMessage {
                Text(error)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.red)
            }
        }
    }
}

/// Minimum Cash Reserve Section Component
struct MinimumCashReserveSection: View {
    @Environment(\.appServices) private var appServices
    @ObservedObject var viewModel: ConfigurationManagementViewModel

    var body: some View {
        ConfigurationInputSection(
            title: "Minimum Cash Reserve",
            description: "Minimum amount users must maintain in their account after purchases",
            currentValue: viewModel.formattedCurrency(appServices.configurationService.minimumCashReserve),
            inputValue: $viewModel.minimumCashReserveInput,
            isValid: viewModel.isValidMinimumCashReserve,
            errorMessage: viewModel.minimumCashReserveError
        ) {
            Task {
                await viewModel.updateMinimumCashReserve(appServices.configurationService)
            }
        }
    }
}

/// Initial Account Balance Section Component
struct InitialAccountBalanceSection: View {
    @Environment(\.appServices) private var appServices
    @ObservedObject var viewModel: ConfigurationManagementViewModel

    var body: some View {
        ConfigurationInputSection(
            title: "Initial Account Balance",
            description: "Starting balance for new user accounts",
            currentValue: viewModel.formattedCurrency(appServices.configurationService.initialAccountBalance),
            inputValue: $viewModel.initialAccountBalanceInput,
            isValid: viewModel.isValidInitialAccountBalance,
            errorMessage: viewModel.initialAccountBalanceError
        ) {
            Task {
                await viewModel.updateInitialAccountBalance(appServices.configurationService)
            }
        }
    }
}

/// Trader Commission Rate Section Component
struct TraderCommissionRateSection: View {
    @Environment(\.appServices) private var appServices
    @ObservedObject var viewModel: ConfigurationManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Trader Commission Rate")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.primary)

                Spacer()

                Text("\(Int(appServices.configurationService.traderCommissionRate * 100))%")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.secondary)
            }

            Text("Percentage of profit that traders receive as commission (0% to 100%)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)

            HStack {
                TextField("Enter rate (0.0-1.0)", value: $viewModel.traderCommissionRateInput, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)

                Text("(\(Int(viewModel.traderCommissionRateInput * 100))%)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 50)

                Button("Update") {
                    Task {
                        await viewModel.updateTraderCommissionRate(appServices.configurationService)
                    }
                }
                .disabled(!viewModel.isValidTraderCommissionRate)
                .buttonStyle(.borderedProminent)
            }

            if let error = viewModel.traderCommissionRateError {
                Text(error)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.red)
            }
        }
    }
}

/// User Minimum Cash Reserve Section Component
struct UserMinimumCashReserveSection: View {
    @Environment(\.appServices) private var appServices
    @ObservedObject var viewModel: ConfigurationManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Per-User Minimum Cash Reserve")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(.primary)

            Text("Set minimum cash reserve for a specific user (trader or investor)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                TextField("User ID", text: $viewModel.userMinimumCashReserveUserId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                HStack {
                    TextField("Enter amount", value: $viewModel.userMinimumCashReserveInput, format: .currency(code: "EUR"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)

                    Button("Update") {
                        Task {
                            await viewModel.updateUserMinimumCashReserve(appServices.configurationService)
                        }
                    }
                    .disabled(!viewModel.isValidUserMinimumCashReserve)
                    .buttonStyle(.borderedProminent)
                }
            }

            if let error = viewModel.userMinimumCashReserveError {
                Text(error)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.red)
            }

            if !viewModel.userMinimumCashReserveUserId.isEmpty {
                let currentValue = appServices.configurationService.getMinimumCashReserve(for: viewModel.userMinimumCashReserveUserId)
                Text("Current value for user: \(currentValue.formattedAsLocalizedCurrency())")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Reset to Defaults Section Component
struct ResetToDefaultsSection: View {
    @ObservedObject var viewModel: ConfigurationManagementViewModel
    @Environment(\.appServices) private var appServices

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Reset Configuration")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(.primary)

            Text("Reset all configuration values to their default settings")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)

            Button("Reset to Defaults") {
                Task {
                    await viewModel.resetToDefaults(appServices.configurationService)
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
}







