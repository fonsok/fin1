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
    @ObservedObject var viewModel: ConfigurationSettingsViewModel

    var body: some View {
        ConfigurationInputSection(
            title: "Minimum Cash Reserve",
            description: "Minimum amount users must maintain in their account after purchases",
            currentValue: viewModel.currentMinimumCashReserveText,
            inputValue: $viewModel.minimumCashReserveInput,
            isValid: viewModel.isValidMinimumCashReserve,
            errorMessage: viewModel.minimumCashReserveError
        ) {
            Task {
                await viewModel.updateMinimumCashReserve()
            }
        }
    }
}

/// Initial Account Balance Section Component
struct InitialAccountBalanceSection: View {
    @ObservedObject var viewModel: ConfigurationSettingsViewModel

    var body: some View {
        ConfigurationInputSection(
            title: "Initial Account Balance",
            description: "Startguthaben für neue Benutzerkonten",
            currentValue: viewModel.currentInitialAccountBalanceText,
            inputValue: $viewModel.initialAccountBalanceInput,
            isValid: viewModel.isValidInitialAccountBalance,
            errorMessage: viewModel.initialAccountBalanceError,
            successMessage: viewModel.initialAccountBalanceSuccess
        ) {
            Task {
                await viewModel.updateInitialAccountBalance()
            }
        }
    }
}

/// Trader Commission Rate Section Component
struct TraderCommissionRateSection: View {
    @ObservedObject var viewModel: ConfigurationSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Trader Commission Rate")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.primary)

                Spacer()

                Text(viewModel.currentTraderCommissionRateText)
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

                Text("(\((viewModel.traderCommissionRateInput * 100).formatted(.number.precision(.fractionLength(0...2))))%)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 50)

                Button("Update") {
                    Task {
                        await viewModel.updateTraderCommissionRate()
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
    @ObservedObject var viewModel: ConfigurationSettingsViewModel

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
                    await viewModel.updateShowCommissionBreakdownInCreditNote()
                }
            }
        }
    }
}

/// Toggle: show document reference deep-links in account statement (default on)
struct ShowDocumentReferenceLinksInAccountStatementSection: View {
    @ObservedObject var viewModel: ConfigurationSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Toggle(isOn: $viewModel.showDocumentReferenceLinksInAccountStatementInput) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Beleg-Links im Kontoauszug anzeigen")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.primary)
                    Text("Wenn aktiv, sind Belegnummern klickbar und öffnen den referenzierten Beleg.")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: viewModel.showDocumentReferenceLinksInAccountStatementInput) { _, _ in
                Task {
                    await viewModel.updateShowDocumentReferenceLinksInAccountStatement()
                }
            }
        }
    }
}

/// User Minimum Cash Reserve Section Component
struct UserMinimumCashReserveSection: View {
    @ObservedObject var viewModel: ConfigurationSettingsViewModel

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
                            await viewModel.updateUserMinimumCashReserve()
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
                let currentValue = viewModel.currentUserMinimumCashReserveText(for: viewModel.userMinimumCashReserveUserId) ?? "-"
                Text("Current value for user: \(currentValue)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Reset to Defaults Section Component
struct ResetToDefaultsSection: View {
    @ObservedObject var viewModel: ConfigurationSettingsViewModel

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
                    await viewModel.resetToDefaults()
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
    @StateObject private var viewModel = PendingApprovalsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(viewModel.pendingCount > 0 ? .orange : .green)

                Text("4-Eyes Approvals")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if viewModel.pendingCount > 0 {
                    Text("\(viewModel.pendingCount) pending")
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
                    Text(viewModel.pendingCount > 0 ? "Review Pending Changes" : "View Approval History")
                        .font(ResponsiveDesign.bodyFont())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(viewModel.pendingCount > 0 ? Color.orange.opacity(0.1) : Color(.secondarySystemBackground))
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ResponsiveDesign.spacing(12))
        .task {
            viewModel.configure(with: appServices.configurationService)
            await viewModel.loadPendingCount()
        }
    }
}
