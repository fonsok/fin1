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
    @State private var selectedDocument: Document?
    @State private var showMissingDocumentAlert = false
    private let summaryColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: ResponsiveDesign.spacing(12)), count: 2)

    init(services: AppServices) {
        _viewModel = StateObject(wrappedValue: AccountStatementViewModel(services: services))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(20)) {
                self.header
                self.summarySection

                if self.viewModel.hasTransactions {
                    self.entriesTable
                } else {
                    self.emptyState
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
                        self.generateAccountStatement()
                    }) {
                        if self.isGeneratingStatement {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.fontColor))
                        } else {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(AppTheme.accentLightBlue)
                        }
                    }
                    .disabled(self.isGeneratingStatement)
                    .accessibilityIdentifier("GenerateStatementButton")
                    .accessibilityLabel("Generate account statement")
                    .accessibilityHint("Creates a monthly account statement document for the current month")

                    Button("Done") {
                        self.dismiss()
                    }
                }
            }
        }
        .task {
            self.viewModel.refresh()
        }
        .alert("Account Statement Generated", isPresented: self.$showGenerationSuccess) {
            Button("OK") { }
        } message: {
            Text("Your monthly account statement has been created and is available in your documents.")
        }
        .alert("Beleg nicht gefunden", isPresented: self.$showMissingDocumentAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Für diese Buchung wurde kein passender Beleg geladen. Bitte Dokumente aktualisieren und erneut versuchen.")
        }
        .sheet(item: self.$selectedDocument) { document in
            DocumentNavigationHelper.sheetView(for: document, appServices: self.services)
        }
    }

    // MARK: - Actions

    private func generateAccountStatement() {
        guard let currentUser = services.userService.currentUser else { return }

        self.isGeneratingStatement = true

        Task {
            await MonthlyAccountStatementGenerator.createMockCurrentMonthStatement(
                for: currentUser,
                services: self.services
            )

            await MainActor.run {
                self.isGeneratingStatement = false
                self.showGenerationSuccess = true
                // Refresh the view to show any new entries
                self.viewModel.refresh()
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Account Statement")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Text(self.viewModel.currentBalance.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.regular)
                .foregroundColor(AppTheme.fontColor.opacity(0.9))

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                Text("Opening balance: \(self.viewModel.openingBalance.formattedAsLocalizedCurrency())")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.9))

                Text(self.viewModel.netChangeFormatted)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(self.viewModel.netChange >= 0 ? AppTheme.accentGreen.opacity(0.9) : AppTheme.accentRed.opacity(0.9))
            }

            Picker("Range", selection: self.$viewModel.selectedRange) {
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
        LazyVGrid(columns: self.summaryColumns, spacing: ResponsiveDesign.spacing(12)) {
            self.summaryCard(
                title: "Credits",
                value: self.viewModel.totalCredits.formattedAsLocalizedCurrency(),
                subtitle: "Inflows",
                color: AppTheme.accentGreen.opacity(0.9)
            )

            self.summaryCard(
                title: "Debits",
                value: self.viewModel.totalDebits.formattedAsLocalizedCurrency(),
                subtitle: "Outflows",
                color: AppTheme.accentRed.opacity(0.6)
            )

            self.summaryCard(
                title: "Net Change",
                value: self.viewModel.netChangeFormatted,
                subtitle: self.viewModel.selectedRange.title,
                color: self.viewModel.netChange >= 0 ? AppTheme.accentGreen.opacity(0.9) : AppTheme.accentRed.opacity(0.6)
            )

            self.withdrawalToVerifiedAccountButton
        }
    }

    private var entriesTable: some View {
        AccountStatementEntriesTable(
            entries: self.viewModel.filteredEntries,
            showDocumentReferenceLinks: self.services.configurationService.showDocumentReferenceLinksInAccountStatement,
            onEntryTap: self.openReferencedDocument(for:)
        )
    }

    private var emptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "list.bullet.rectangle")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(40)))
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

    private func openReferencedDocument(for entry: AccountStatementEntry) {
        if let cached = entry.referencedDocument(documentService: services.documentService) {
            self.selectedDocument = cached
            return
        }
        Task { @MainActor in
            if let resolved = await entry.resolveReferencedDocument(documentService: services.documentService) {
                self.selectedDocument = resolved
            } else {
                self.showMissingDocumentAlert = true
            }
        }
    }

    private var withdrawalToVerifiedAccountButton: some View {
        Button {
            self.showWithdrawalInfo = true
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
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(12)))
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
        .alert("Withdrawal to verified account", isPresented: self.$showWithdrawalInfo) {
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
