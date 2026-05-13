import SwiftUI

struct BankContraLedgerView: View {
    @StateObject private var viewModel: BankContraLedgerViewModel

    init(viewModel: BankContraLedgerViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                self.filterSection
                self.totalsSection
                self.ledgerSection
            }
            .padding()
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Bank Ledger")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    self.viewModel.copyCSVToPasteboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy CSV to clipboard")

                Button {
                    self.viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh ledger")
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Filters")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)

            Picker("Account", selection: Binding(
                get: { self.viewModel.selectedAccount },
                set: { self.viewModel.selectedAccount = $0 }
            )) {
                Text("All Accounts").tag(nil as BankContraAccount?)
                ForEach(BankContraAccount.allCases, id: \.self) { account in
                    Text(account.displayName).tag(account as BankContraAccount?)
                }
            }
            .pickerStyle(.menu)

            TextField("Investor ID contains…", text: self.$viewModel.investorFilter)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Toggle("Filter by start date", isOn: Binding(
                    get: { self.viewModel.startDate != nil },
                    set: { enabled in
                        self.viewModel.startDate = enabled ? (self.viewModel.startDate ?? Date()) : nil
                    }
                ))
                if let _ = viewModel.startDate {
                    DatePicker(
                        "Start Date",
                        selection: Binding(
                            get: { self.viewModel.startDate ?? Date() },
                            set: { self.viewModel.startDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }

                Toggle("Filter by end date", isOn: Binding(
                    get: { self.viewModel.endDate != nil },
                    set: { enabled in
                        self.viewModel.endDate = enabled ? (self.viewModel.endDate ?? Date()) : nil
                    }
                ))
                if let _ = viewModel.endDate {
                    DatePicker(
                        "End Date",
                        selection: Binding(
                            get: { self.viewModel.endDate ?? Date() },
                            set: { self.viewModel.endDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }
            }

            Button("Clear Filters") {
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

    private var totalsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Account Balances")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)

            if self.viewModel.totalsByAccount.isEmpty {
                Text("No entries for the selected filters.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
            } else {
                ForEach(BankContraAccount.allCases, id: \.self) { account in
                    if let total = viewModel.totalsByAccount[account] {
                        HStack {
                            Text(account.displayName)
                            Spacer()
                            Text(total.formatted(.currency(code: "EUR")))
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 4)
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

    private var ledgerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Ledger Entries")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)

            if self.viewModel.entries.isEmpty {
                Text("No ledger entries match the current filters.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                    ForEach(self.viewModel.entries) { entry in
                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
                            HStack {
                                Text(entry.accountName)
                                    .font(ResponsiveDesign.bodyFont())
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(entry.amountText)
                                    .font(ResponsiveDesign.bodyFont())
                                    .foregroundColor(entry.sideText == "Credit" ? AppTheme.accentGreen : AppTheme.accentRed)
                            }

                            Text(entry.createdAtText)
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Label(entry.sideText, systemImage: "arrow.triangle.2.circlepath")
                                    .font(ResponsiveDesign.captionFont())
                                Label("Investor: \(entry.investorId)", systemImage: "person")
                                    .font(ResponsiveDesign.captionFont())
                                Label("Batch: \(entry.batchId)", systemImage: "shippingbox")
                                    .font(ResponsiveDesign.captionFont())
                                Label("Reference: \(entry.reference)", systemImage: "number")
                                    .font(ResponsiveDesign.captionFont())
                            }

                            if !entry.investmentList.isEmpty {
                                Text("Investments:\n\(entry.investmentList)")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(.secondary)
                            }

                            if entry.metadataDescription != "—" {
                                Text("Metadata:\n\(entry.metadataDescription)")
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
                }
            }
        }
    }
}

#Preview {
    let postingService = BankContraAccountPostingService()
    let vm = BankContraLedgerViewModel(postingService: postingService)
    return NavigationStack {
        BankContraLedgerView(viewModel: vm)
    }
}
