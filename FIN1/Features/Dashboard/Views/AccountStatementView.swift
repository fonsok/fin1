import SwiftUI

// MARK: - Account Statement View
/// Displays account statement with transaction history for both investors and traders
struct AccountStatementView: View {
    @StateObject private var viewModel: AccountStatementViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var services
    @State private var isGeneratingStatement = false
    @State private var showGenerationSuccess = false
    @State private var showWithdrawalInfo = false
    private let summaryColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: ResponsiveDesign.spacing(12)), count: 2)

    init(services: AppServices) {
        _viewModel = StateObject(wrappedValue: AccountStatementViewModel(services: services))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(20)) {
                header
                summarySection

                if viewModel.hasTransactions {
                    entriesTable
                } else {
                    emptyState
                }

                AccountStatementImportantNoticesView()
            }
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            .padding(.vertical, ResponsiveDesign.spacing(20))
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Account Statement")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    Button(action: {
                        generateAccountStatement()
                    }) {
                        if isGeneratingStatement {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.fontColor))
                        } else {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(AppTheme.accentLightBlue)
                        }
                    }
                    .disabled(isGeneratingStatement)
                    .accessibilityIdentifier("GenerateStatementButton")
                    .accessibilityLabel("Generate account statement")
                    .accessibilityHint("Creates a monthly account statement document for the current month")

                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            viewModel.refresh()
        }
        .alert("Account Statement Generated", isPresented: $showGenerationSuccess) {
            Button("OK") { }
        } message: {
            Text("Your monthly account statement has been created and is available in your documents.")
        }
    }

    // MARK: - Actions

    private func generateAccountStatement() {
        guard let currentUser = services.userService.currentUser else { return }

        isGeneratingStatement = true

        Task {
            await MonthlyAccountStatementGenerator.createMockCurrentMonthStatement(
                for: currentUser,
                services: services
            )

            await MainActor.run {
                isGeneratingStatement = false
                showGenerationSuccess = true
                // Refresh the view to show any new entries
                viewModel.refresh()
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Account Statement")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Text(viewModel.currentBalance.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.regular)
                .foregroundColor(AppTheme.fontColor.opacity(0.9))

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                Text("Opening balance: \(viewModel.openingBalance.formattedAsLocalizedCurrency())")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.9))

                Text(viewModel.netChangeFormatted)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(viewModel.netChange >= 0 ? AppTheme.accentGreen.opacity(0.9) : AppTheme.accentRed.opacity(0.9))
            }

            Picker("Range", selection: $viewModel.selectedRange) {
                ForEach(AccountStatementRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(ResponsiveDesign.spacing(20))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.sectionBackground.opacity(0.5))
        .cornerRadius(ResponsiveDesign.spacing(16))
    }

    private var summarySection: some View {
        LazyVGrid(columns: summaryColumns, spacing: ResponsiveDesign.spacing(12)) {
            summaryCard(
                title: "Credits",
                value: viewModel.totalCredits.formattedAsLocalizedCurrency(),
                subtitle: "Inflows",
                color: AppTheme.accentGreen.opacity(0.9)
            )

            summaryCard(
                title: "Debits",
                value: viewModel.totalDebits.formattedAsLocalizedCurrency(),
                subtitle: "Outflows",
                color: AppTheme.accentRed.opacity(0.6)
            )

            summaryCard(
                title: "Net Change",
                value: viewModel.netChangeFormatted,
                subtitle: viewModel.selectedRange.title,
                color: viewModel.netChange >= 0 ? AppTheme.accentGreen.opacity(0.9) : AppTheme.accentRed.opacity(0.6)
            )

            withdrawalToVerifiedAccountButton
        }
    }

    private var entriesTable: some View {
        AccountStatementEntriesTable(entries: viewModel.filteredEntries)
    }

    private var emptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: ResponsiveDesign.spacing(40)))
                .foregroundColor(AppTheme.fontColor.opacity(0.4))

            Text("No transactions")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            Text("Once there are transactions in the selected period, they will appear here.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(ResponsiveDesign.spacing(32))
        .background(AppTheme.sectionBackground.opacity(0.3))
        .cornerRadius(ResponsiveDesign.spacing(16))
    }

    // MARK: - Helpers

    private func summaryCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
            Text(title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))

            Text(value)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(color)

            Text(subtitle)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
        }
        .padding(ResponsiveDesign.spacing(16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.sectionBackground.opacity(0.3))
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var withdrawalToVerifiedAccountButton: some View {
        Button {
            showWithdrawalInfo = true
        } label: {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: "arrow.down.left")
                    .foregroundColor(AppTheme.accentOrange.opacity(0.6))

                Text("Withdrawal to verified account")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.regular)
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: ResponsiveDesign.spacing(12)))
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            }
            .padding(ResponsiveDesign.spacing(12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.sectionBackground.opacity(0.35))
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("WithdrawalToVerifiedAccountButton")
        .accessibilityLabel("Withdrawal to verified account")
        .accessibilityHint("Start a withdrawal to your verified payout account")
        .alert("Withdrawal to verified account", isPresented: $showWithdrawalInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Withdrawals are processed to the verified payout account on file. This action will connect to the withdrawal flow.")
        }
    }

}

// MARK: - ViewModel Extension

extension AccountStatementViewModel {
    var netChangeFormatted: String {
        let prefix = netChange >= 0 ? "+" : "−"
        return "\(prefix)\(abs(netChange).formattedAsLocalizedCurrency())"
    }
}
