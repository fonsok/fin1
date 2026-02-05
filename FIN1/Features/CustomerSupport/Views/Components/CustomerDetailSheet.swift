import SwiftUI

// MARK: - Customer Detail Sheet

struct CustomerDetailSheet: View {
    let customer: CustomerProfile
    let kycStatus: CustomerKYCStatus?
    let investments: [CustomerInvestmentSummary]
    let documents: [CustomerDocumentSummary]
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTicket: SupportTicket?
    @State private var selectedInvestment: CustomerInvestmentSummary?
    @State private var selectedTrade: CustomerTradeSummary?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    customerHeader
                    if let kyc = kycStatus {
                        kycStatusSection(kyc)
                    }
                    contactSection
                    // Role-based display: Investments for investors, Trades for traders
                    if customer.role.lowercased() == "investor" && viewModel.hasPermission(.viewCustomerInvestments) {
                        investmentsSection
                    }
                    if customer.role.lowercased() == "trader" && viewModel.hasPermission(.viewCustomerTrades) {
                        tradesSection
                    }
                    if viewModel.hasPermission(.viewCustomerDocuments) {
                        documentsSection
                    }
                    if viewModel.hasPermission(.viewCustomerSupportHistory) {
                        ticketsSection
                    }
                    actionsSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Kundendetails")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        viewModel.clearSelectedCustomer()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCreateTicketSheet) {
                CreateTicketSheet(viewModel: viewModel)
            }
            .sheet(item: $selectedTicket) { ticket in
                TicketDetailSheet(ticket: ticket, viewModel: viewModel)
            }
            .sheet(item: $selectedInvestment) { investment in
                CSRInvestmentDetailSheet(
                    investment: investment,
                    customerName: customer.fullName
                )
            }
            .sheet(item: $selectedTrade) { trade in
                CSRTradeDetailSheet(
                    trade: trade,
                    customerName: customer.fullName
                )
            }
            .task {
                await viewModel.loadCustomerTickets(customerId: customer.customerId)
            }
        }
    }

    // MARK: - Customer Header

    private var customerHeader: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Circle()
                .fill(AppTheme.accentLightBlue.opacity(0.2))
                .frame(width: ResponsiveDesign.spacing(80), height: ResponsiveDesign.spacing(80))
                .overlay(
                    Text(customer.fullName.prefix(2).uppercased())
                        .font(ResponsiveDesign.titleFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.accentLightBlue)
                )

            Text(customer.fullName)
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text("Kundennummer: \(customer.customerId)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                CSStatusBadge(text: customer.role.capitalized, color: AppTheme.accentLightBlue)
                CSStatusBadge(
                    text: customer.accountStatus.displayName,
                    color: customer.accountStatus == .active ? AppTheme.accentGreen : AppTheme.accentOrange
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - KYC Status Section

    private func kycStatusSection(_ kyc: CustomerKYCStatus) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(AppTheme.accentGreen)

                Text("KYC-Status")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                CSStatusBadge(text: kyc.overallStatus.displayName, color: kycStatusColor(kyc.overallStatus))
            }

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                KYCStatusRow(title: "E-Mail verifiziert", isComplete: kyc.emailVerified)
                KYCStatusRow(title: "Identität verifiziert", isComplete: kyc.identityVerified)
                KYCStatusRow(title: "Adresse verifiziert", isComplete: kyc.addressVerified)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private func kycStatusColor(_ status: CustomerKYCStatus.KYCOverallStatus) -> Color {
        switch status {
        case .complete: return AppTheme.accentGreen
        case .inProgress, .pendingReview: return AppTheme.accentOrange
        case .rejected, .expired: return AppTheme.accentRed
        }
    }

    // MARK: - Contact Section

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Kontaktdaten")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                CSContactInfoRow(icon: "envelope.fill", label: "E-Mail", value: customer.email)
                CSContactInfoRow(icon: "phone.fill", label: "Telefon", value: customer.phoneNumber)
                if let address = customer.formattedAddress {
                    CSContactInfoRow(icon: "location.fill", label: "Adresse", value: address)
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Investments Section

    private var investmentsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Investments")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                // Time period filter dropdown
                Menu {
                    ForEach(InvestmentTimePeriod.allCases, id: \.self) { period in
                        Button(action: {
                            viewModel.selectedInvestmentTimePeriod = period
                        }) {
                            HStack {
                                Text(period.displayName)
                                if viewModel.selectedInvestmentTimePeriod == period {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Text(viewModel.selectedInvestmentTimePeriod.displayName)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentLightBlue)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.accentLightBlue)
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(8))
                    .padding(.vertical, ResponsiveDesign.spacing(4))
                    .background(AppTheme.accentLightBlue.opacity(0.1))
                    .cornerRadius(ResponsiveDesign.spacing(6))
                }
            }

            let ongoingInvestments = viewModel.filteredInvestmentsByTimePeriod.filter { investment in
                investment.status.lowercased() == "active" || investment.status.lowercased() == "submitted"
            }
            let completedInvestments = viewModel.filteredInvestmentsByTimePeriod.filter { investment in
                investment.status.lowercased() == "completed" || investment.status.lowercased() == "cancelled"
            }

            if viewModel.filteredInvestmentsByTimePeriod.isEmpty {
                Text("Keine Investments vorhanden")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding()
            } else {
                if !ongoingInvestments.isEmpty {
                    Text("Laufende Investments")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, ResponsiveDesign.spacing(4))

                    ForEach(ongoingInvestments) { investment in
                        InvestmentSummaryCard(investment: investment) {
                            selectedInvestment = investment
                        }
                    }
                }

                if !completedInvestments.isEmpty {
                    if !ongoingInvestments.isEmpty {
                        Divider()
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                    }

                    Text("Abgeschlossene Investments")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(completedInvestments) { investment in
                        InvestmentSummaryCard(investment: investment) {
                            selectedInvestment = investment
                        }
                    }
                }

                // Show message if filtered list has items but none match ongoing/completed status
                if ongoingInvestments.isEmpty && completedInvestments.isEmpty && !viewModel.filteredInvestmentsByTimePeriod.isEmpty {
                    Text("Keine Investments im ausgewählten Zeitraum")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .padding()
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Trades Section

    private var tradesSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Trades")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                // Time period filter dropdown
                Menu {
                    ForEach(InvestmentTimePeriod.allCases, id: \.self) { period in
                        Button(action: {
                            viewModel.selectedTradeTimePeriod = period
                        }) {
                            HStack {
                                Text(period.displayName)
                                if viewModel.selectedTradeTimePeriod == period {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Text(viewModel.selectedTradeTimePeriod.displayName)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentLightBlue)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.accentLightBlue)
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(8))
                    .padding(.vertical, ResponsiveDesign.spacing(4))
                    .background(AppTheme.accentLightBlue.opacity(0.1))
                    .cornerRadius(ResponsiveDesign.spacing(6))
                }
            }

            if viewModel.filteredTradesByTimePeriod.isEmpty {
                Text("Keine Trades vorhanden")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding()
            } else {
                if !viewModel.ongoingTrades.isEmpty {
                    Text("Laufende Trades")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, ResponsiveDesign.spacing(4))

                    ForEach(viewModel.ongoingTrades) { trade in
                        TradeSummaryCard(trade: trade) {
                            selectedTrade = trade
                        }
                    }
                }

                if !viewModel.completedTrades.isEmpty {
                    if !viewModel.ongoingTrades.isEmpty {
                        Divider()
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                    }

                    Text("Abgeschlossene Trades")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(viewModel.completedTrades) { trade in
                        TradeSummaryCard(trade: trade) {
                            selectedTrade = trade
                        }
                    }
                }

                // Show message if filtered list has items but none match ongoing/completed status
                if viewModel.ongoingTrades.isEmpty && viewModel.completedTrades.isEmpty && !viewModel.filteredTradesByTimePeriod.isEmpty {
                    Text("Keine Trades im ausgewählten Zeitraum")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .padding()
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Documents Section

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(AppTheme.accentOrange)

                Text("Dokumente")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                if !documents.isEmpty {
                    Text("\(documents.count)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                        .background(AppTheme.accentOrange.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.spacing(6))
                }
            }

            if documents.isEmpty {
                Text("Keine Dokumente vorhanden")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding()
            } else {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(documents) { document in
                        DocumentRow(document: document)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Tickets Section

    private var ticketsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(AppTheme.accentLightBlue)

                Text("Support-Tickets")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                if viewModel.isLoadingCustomerTickets {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !viewModel.customerTickets.isEmpty {
                    Text("\(viewModel.customerTickets.count)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                        .background(AppTheme.accentLightBlue.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.spacing(6))
                }
            }

            if viewModel.isLoadingCustomerTickets {
                HStack {
                    Spacer()
                    ProgressView("Lade Tickets...")
                        .font(ResponsiveDesign.captionFont())
                    Spacer()
                }
                .padding()
            } else if viewModel.customerTickets.isEmpty {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "tray")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.3))

                    Text("Keine Support-Tickets vorhanden")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    if !viewModel.activeCustomerTickets.isEmpty {
                        Text("Aktive Tickets")
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(viewModel.activeCustomerTickets) { ticket in
                            CustomerTicketRow(ticket: ticket, viewModel: viewModel) {
                                selectedTicket = ticket
                            }
                        }
                    }

                    if !viewModel.closedCustomerTickets.isEmpty {
                        if !viewModel.activeCustomerTickets.isEmpty {
                            Divider()
                                .padding(.vertical, ResponsiveDesign.spacing(4))
                        }

                        Text("Abgeschlossene Tickets")
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(viewModel.closedCustomerTickets.prefix(3)) { ticket in
                            CustomerTicketRow(ticket: ticket, viewModel: viewModel) {
                                selectedTicket = ticket
                            }
                        }

                        if viewModel.closedCustomerTickets.count > 3 {
                            Text("+ \(viewModel.closedCustomerTickets.count - 3) weitere abgeschlossene Tickets")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.accentLightBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.top, ResponsiveDesign.spacing(4))
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Aktionen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                if viewModel.hasPermission(.createSupportTicket) {
                    CSActionButton(
                        icon: "ticket.fill",
                        title: "Support-Ticket erstellen",
                        color: AppTheme.accentLightBlue
                    ) {
                        viewModel.openCreateTicketSheet(customerId: customer.customerId)
                    }
                }

                if viewModel.hasPermission(.resetCustomerPassword) {
                    CSActionButton(
                        icon: "key.fill",
                        title: "Passwort zurücksetzen",
                        color: AppTheme.accentOrange
                    ) {
                        Task {
                            await viewModel.initiatePasswordReset(customerId: customer.customerId)
                        }
                    }
                }

                if viewModel.hasPermission(.unlockCustomerAccount) && customer.accountStatus == .locked {
                    CSActionButton(
                        icon: "lock.open.fill",
                        title: "Konto entsperren",
                        color: AppTheme.accentGreen
                    ) {
                        Task {
                            await viewModel.unlockAccount(customerId: customer.customerId, reason: "Kundenanfrage")
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

