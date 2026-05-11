import SwiftUI

// MARK: - Monthly Account Statement View
/// Renders a calendar-month account statement using the same table layout
/// as `AccountStatementView`, based on existing `AccountStatementEntry` data.
struct MonthlyAccountStatementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var services
    @StateObject private var viewModel: MonthlyAccountStatementViewModel
    @State private var selectedDocument: Document?
    @State private var showMissingDocumentAlert = false

    init(services: AppServices, document: Document) {
        let year = document.statementYear ?? Calendar.current.component(.year, from: Date())
        let month = document.statementMonth ?? Calendar.current.component(.month, from: Date())
        _viewModel = StateObject(
            wrappedValue: MonthlyAccountStatementViewModel(
                services: services,
                year: year,
                month: month
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(20)) {
                // Header and summary with horizontal padding
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    header
                    summarySection
                }
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

                // Entries table - full width for horizontal scrolling in landscape
                if viewModel.hasTransactions {
                    entriesTable
                        .padding(.horizontal, ResponsiveDesign.spacing(4))
                } else {
                    emptyState
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                }

                // Important notices with horizontal padding
                AccountStatementImportantNoticesView()
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            }
            .padding(.vertical, ResponsiveDesign.spacing(20))
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(viewModel.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            viewModel.load()
        }
        .alert("Beleg nicht gefunden", isPresented: $showMissingDocumentAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Für diese Buchung wurde kein passender Beleg geladen. Bitte Dokumente aktualisieren und erneut versuchen.")
        }
        .sheet(item: $selectedDocument) { document in
            DocumentNavigationHelper.sheetView(for: document, appServices: services)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Monthly Account Statement")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Text(viewModel.closingBalance.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.regular)
                .foregroundColor(AppTheme.fontColor)

            Text("Opening balance: \(viewModel.openingBalance.formattedAsLocalizedCurrency())")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                Text(viewModel.periodLabel)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))

                Text(viewModel.netChangeFormatted)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(viewModel.netChange >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
            }
        }
        .padding(ResponsiveDesign.spacing(20))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.sectionBackground.opacity(0.5))
        .cornerRadius(ResponsiveDesign.spacing(16))
    }

    private var summarySection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                summaryCard(
                    title: "Credits",
                    value: viewModel.totalCredits.formattedAsLocalizedCurrency(),
                    subtitle: "Inflows",
                    color: AppTheme.accentGreen
                )

                summaryCard(
                    title: "Debits",
                    value: viewModel.totalDebits.formattedAsLocalizedCurrency(),
                    subtitle: "Outflows",
                    color: AppTheme.accentRed
                )
            }

            summaryCard(
                title: "Net Change",
                value: viewModel.netChangeFormatted,
                subtitle: viewModel.periodLabel,
                color: viewModel.netChange >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
            )
        }
    }

    private var entriesTable: some View {
        AccountStatementEntriesTable(
            entries: viewModel.entries,
            showDocumentReferenceLinks: services.configurationService.showDocumentReferenceLinksInAccountStatement,
            onEntryTap: openReferencedDocument(for:)
        ) {
            statementMetaHeader
        }
    }

    private func openReferencedDocument(for entry: AccountStatementEntry) {
        if let cached = entry.referencedDocument(documentService: services.documentService) {
            selectedDocument = cached
            return
        }
        Task { @MainActor in
            if let resolved = await entry.resolveReferencedDocument(documentService: services.documentService) {
                selectedDocument = resolved
            } else {
                showMissingDocumentAlert = true
            }
        }
    }

    private var statementMetaHeader: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            // Row 1: Account statement period
            HStack {
                Text("Account statement from")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                Text(viewModel.periodLabel)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
            }
            .padding(.horizontal, AccountStatementTableLayout.tableHorizontalPadding)
            .padding(.top, ResponsiveDesign.spacing(6))

            // Row 2: Account holder
            HStack {
                Text("Account holder:")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                Text(viewModel.accountHolderName)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
            }
            .padding(.horizontal, AccountStatementTableLayout.tableHorizontalPadding)
            .padding(.bottom, ResponsiveDesign.spacing(6))

            Divider()
                .background(AppTheme.fontColor.opacity(0.4))

            // Row 3: Meta table header (Statement No. | Page | of | IBAN | Opening balance as of ...)
            HStack(spacing: AccountStatementTableLayout.columnSpacing) {
                Text("Statement No.")
                    .frame(width: AccountStatementTableLayout.combinedDateColumnWidth, alignment: .leading)
                Text("Page")
                    .frame(width: AccountStatementTableLayout.amountColumnWidth, alignment: .leading)
                Text("of")
                    .frame(width: AccountStatementTableLayout.amountColumnWidth, alignment: .leading)
                Text("IBAN")
                    .frame(width: AccountStatementTableLayout.descriptionColumnWidth, alignment: .leading)
                Text("Opening balance as of \(viewModel.openingBalanceDateLabel)")
                    .frame(width: AccountStatementTableLayout.amountColumnWidth, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.medium)
            .foregroundColor(AppTheme.fontColor)
            .padding(.horizontal, AccountStatementTableLayout.tableHorizontalPadding)
            .padding(.top, ResponsiveDesign.spacing(4))
            .padding(.bottom, ResponsiveDesign.spacing(2))

            // Row 4: Meta table values (e.g. 9 | 1 | 1 | DE... | EUR +12,345.78)
            HStack(spacing: AccountStatementTableLayout.columnSpacing) {
                Text("\(viewModel.statementNumber)")
                    .frame(width: AccountStatementTableLayout.combinedDateColumnWidth, alignment: .leading)
                Text("1")
                    .frame(width: AccountStatementTableLayout.amountColumnWidth, alignment: .leading)
                Text("1")
                    .frame(width: AccountStatementTableLayout.amountColumnWidth, alignment: .leading)
                Text(viewModel.accountIbanDisplay)
                    .frame(width: AccountStatementTableLayout.descriptionColumnWidth, alignment: .leading)
                HStack {
                  //  Text("EUR")
                    Text(viewModel.openingBalance.formattedAsLocalizedCurrency())
                }
                .frame(width: AccountStatementTableLayout.amountColumnWidth, alignment: .trailing)
            }
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(AppTheme.fontColor)
            .padding(.horizontal, AccountStatementTableLayout.tableHorizontalPadding)
            .padding(.top, ResponsiveDesign.spacing(2))
            .padding(.bottom, ResponsiveDesign.spacing(4))
        }
        .frame(minWidth: AccountStatementTableLayout.totalTableWidth, alignment: .leading)
        .background(AppTheme.sectionBackground.opacity(0.35))
        .overlay(
            Rectangle()
                .stroke(AppTheme.fontColor.opacity(0.4), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "list.bullet.rectangle")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(40)))
                .foregroundColor(AppTheme.fontColor.opacity(0.4))

            Text("No transactions for this month")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            Text("Once there are transactions in this month, a statement will appear here.")
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
}
