import SwiftUI

struct AppLedgerView: View {
    @StateObject private var viewModel: AppLedgerViewModel
    @Environment(\.appServices) private var services

    init(viewModel: AppLedgerViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                self.revenueSummarySection
                self.accountSummarySection
                self.filterSection
                self.ledgerSection
            }
            .padding()
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("App Ledger")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let parseAPIClient = services.parseAPIClient {
                    NavigationLink {
                        DocumentSearchView(searchService: DocumentSearchAPIService(parseAPIClient: parseAPIClient))
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .help("Beleg-Suche")
                }

                Button {
                    self.viewModel.copyCSVToPasteboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("CSV kopieren")

                Button {
                    self.viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Aktualisieren")
            }
        }
    }

    // MARK: - Revenue Summary

    private var revenueSummarySection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                self.summaryCard(
                    title: "Gesamterlös",
                    value: self.viewModel.totalRevenue,
                    color: AppTheme.accentGreen,
                    subtitle: "\(self.viewModel.entries.count) Buchungen"
                )
                if let vat = viewModel.vatSummary {
                    self.summaryCard(
                        title: "USt-Verbindlichkeit",
                        value: vat.outstandingVATLiability,
                        color: .blue,
                        subtitle: "Kassiert: \(vat.outputVATCollected.formatted(.currency(code: "EUR")))"
                    )
                }
            }

            if let vat = viewModel.vatSummary {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    self.summaryCard(
                        title: "USt abgeführt",
                        value: vat.outputVATRemitted,
                        color: .purple,
                        subtitle: "An Finanzamt"
                    )
                    self.summaryCard(
                        title: "Vorsteuer",
                        value: vat.inputVATClaimed,
                        color: .orange,
                        subtitle: "Verrechenbar"
                    )
                }
            }
        }
    }

    private func summaryCard(title: String, value: Double, color: Color, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)
            Text(value.formatted(.currency(code: "EUR")))
                .font(ResponsiveDesign.scaledSystemFont(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(subtitle)
                .font(ResponsiveDesign.scaledSystemFont(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .fill(AppTheme.sectionBackground)
        )
    }

    // MARK: - Account Summaries

    private var accountSummarySection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Eigenkonten")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)

            if self.viewModel.accountSummaries.isEmpty {
                Text("Noch keine Buchungen vorhanden.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
            } else {
                ForEach(AppLedgerAccount.AccountGroup.allCases, id: \.self) { group in
                    let groupSummaries = self.viewModel.accountSummaries.filter { $0.account.accountGroup == group }
                    if !groupSummaries.isEmpty {
                        Text(group.displayName)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        ForEach(groupSummaries) { summary in
                            self.accountRow(summary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .fill(AppTheme.sectionBackground)
        )
    }

    private func accountRow(_ summary: AppLedgerAccountSummary) -> some View {
        Button {
            if self.viewModel.selectedAccount == summary.account {
                self.viewModel.selectedAccount = nil
            } else {
                self.viewModel.selectedAccount = summary.account
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.account.displayName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                    Text(summary.account.rawValue)
                        .font(ResponsiveDesign.scaledSystemFont(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(summary.netBalance.formatted(.currency(code: "EUR")))
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(summary.netBalance >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                    Text("H: \(summary.totalCredits.formatted(.currency(code: "EUR")))")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(
            self.viewModel.selectedAccount == summary.account
                ? Color.accentColor.opacity(0.08)
                : Color.clear
        )
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    // MARK: - Filters

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Filter")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)

            Picker("Konto", selection: Binding(
                get: { self.viewModel.selectedAccount },
                set: { self.viewModel.selectedAccount = $0 }
            )) {
                Text("Alle Konten").tag(nil as AppLedgerAccount?)
                ForEach(AppLedgerAccount.allCases, id: \.self) { account in
                    Text(account.displayName).tag(account as AppLedgerAccount?)
                }
            }
            .pickerStyle(.menu)

            TextField("User-ID filtern…", text: self.$viewModel.userFilter)
                .textFieldStyle(.roundedBorder)

            Button("Filter zurücksetzen") {
                self.viewModel.clearFilters()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .fill(AppTheme.sectionBackground)
        )
    }

    // MARK: - Ledger Entries

    private var ledgerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Buchungen (\(self.viewModel.entries.count))")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)

            if self.viewModel.entries.isEmpty {
                Text("Keine Buchungen für die gewählten Filter.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                    ForEach(self.viewModel.entries) { entry in
                        self.entryCard(entry)
                    }
                }
            }
        }
    }

    private func entryCard(_ entry: AppLedgerEntryDisplay) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.accountName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                    Text(entry.transactionType)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.amountText)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(entry.rawEntry.side == .credit ? AppTheme.accentGreen : AppTheme.accentRed)
                    Text(entry.sideText)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                }
            }

            Text(entry.createdAtText)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)

            if !entry.description.isEmpty {
                Text(entry.description)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
            }

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Label(entry.userId, systemImage: "person")
                    .font(ResponsiveDesign.captionFont())
                Label(entry.referenceId, systemImage: "number")
                    .font(ResponsiveDesign.captionFont())
            }
            .foregroundColor(.secondary)

            if let docLink = Self.documentLink(from: entry.rawEntry) {
                NavigationLink {
                    AppLedgerDocumentDetailView(documentObjectId: docLink.objectId)
                } label: {
                    Label(docLink.label, systemImage: "doc.text.magnifyingglass")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            } else if let docNumber = Self.documentNumberOnly(from: entry.rawEntry) {
                Label("Beleg \(docNumber)", systemImage: "doc.text")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .fill(AppTheme.sectionBackground)
        )
    }

    private struct LedgerDocumentLink {
        let objectId: String
        let label: String
    }

    /// Generic resolver for "Beleg ansehen" link on any ledger entry whose metadata carries
    /// `referenceDocumentId` (set by backend triggers for invoices, eigenbelege, settlement docs, …).
    private static func documentLink(from entry: AppLedgerEntry) -> LedgerDocumentLink? {
        let raw = entry.metadata["referenceDocumentId"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        let number = entry.metadata["referenceDocumentNumber"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let label = number.isEmpty ? "Beleg ansehen" : "Beleg \(number) ansehen"
        return LedgerDocumentLink(objectId: raw, label: label)
    }

    /// Falls nur die Belegnummer im Metadata ist (z. B. legacy rows), zeigen wir sie wenigstens textuell.
    private static func documentNumberOnly(from entry: AppLedgerEntry) -> String? {
        let number = entry.metadata["referenceDocumentNumber"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return number.isEmpty ? nil : number
    }
}

#Preview {
    let service = PreviewAppLedgerService()
    let vm = AppLedgerViewModel(ledgerService: service)
    return NavigationStack {
        AppLedgerView(viewModel: vm)
    }
}

private final class PreviewAppLedgerService: AppLedgerServiceProtocol {
    func start() {}
    func stop() {}
    func reset() {}
    func refreshFromBackend() async throws {}
    func getEntries(account: AppLedgerAccount?, userId: String?, transactionType: AppLedgerTransactionType?) -> [AppLedgerEntry] { [] }
    func getAllEntries() -> [AppLedgerEntry] { [] }
    func getAccountSummaries() -> [AppLedgerAccountSummary] { [] }
    func getTotalAppRevenue() -> Double { 0 }
    func getVATSummary() -> AppVATSummary {
        AppVATSummary(outputVATCollected: 0, outputVATRemitted: 0, inputVATClaimed: 0)
    }
}
