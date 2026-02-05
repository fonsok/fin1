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
    var successMessage: String? = nil
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

            if let success = successMessage {
                Text(success)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.green)
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
            errorMessage: viewModel.initialAccountBalanceError,
            successMessage: viewModel.initialAccountBalanceSuccess
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

            if let success = viewModel.traderCommissionRateSuccess {
                Text(success)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.green)
            }
        }
    }
}

/// Show Commission Breakdown in Credit Note Section (Trader Gutschrift)
struct ShowCommissionBreakdownInCreditNoteSection: View {
    @Environment(\.appServices) private var appServices
    @ObservedObject var viewModel: ConfigurationManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Toggle(isOn: $viewModel.showCommissionBreakdownInCreditNoteInput) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Commission-Breakdown in Gutschrift anzeigen")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.primary)
                    Text("Zeigt oder blendet die Tabelle mit Investor-Aufschlüsselung in der Trader-Gutschrift ein.")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: viewModel.showCommissionBreakdownInCreditNoteInput) { _, _ in
                Task {
                    await viewModel.updateShowCommissionBreakdownInCreditNote(appServices.configurationService)
                }
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

// MARK: - Pending Approvals Section
/// Shows pending 4-eyes configuration change requests
struct PendingApprovalsSection: View {
    @Environment(\.appServices) private var appServices
    @State private var pendingCount = 0
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(pendingCount > 0 ? .orange : .green)

                Text("4-Eyes Approvals")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if pendingCount > 0 {
                    Text("\(pendingCount) pending")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                } else {
                    Text("All approved")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.green)
                }
            }

            Text("Critical configuration changes require approval from a second administrator (4-eyes principle).")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)

            NavigationLink {
                PendingConfigurationChangesView()
            } label: {
                HStack {
                    Text(pendingCount > 0 ? "Review Pending Changes" : "View Approval History")
                        .font(ResponsiveDesign.bodyFont())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(pendingCount > 0 ? Color.orange.opacity(0.1) : Color(.secondarySystemBackground))
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ResponsiveDesign.spacing(12))
        .task {
            await loadPendingCount()
        }
    }

    private func loadPendingCount() async {
        isLoading = true
        guard let service = appServices.configurationService as? ConfigurationService else {
            isLoading = false
            return
        }

        do {
            let changes = try await service.getPendingConfigurationChanges()
            pendingCount = changes.count
        } catch {
            pendingCount = 0
        }
        isLoading = false
    }
}



