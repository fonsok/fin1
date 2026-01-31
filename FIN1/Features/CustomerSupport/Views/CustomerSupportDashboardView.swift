import SwiftUI

// MARK: - Customer Support Dashboard View
/// Main dashboard for Customer Support Representatives
/// Provides read-only customer data access with audited actions

struct CustomerSupportDashboardView: View {
    @Environment(\.appServices) private var services
    @StateObject private var viewModel: CustomerSupportDashboardViewModel

    init(services: AppServices? = nil) {
        let appServices = services ?? AppServices.live
        let supportService = appServices.customerSupportService
        let auditService = appServices.auditLoggingService
        let searchCoordinator = CustomerSupportSearchCoordinator(supportService: supportService)

        _viewModel = StateObject(wrappedValue: CustomerSupportDashboardViewModel(
            supportService: supportService,
            auditService: auditService,
            searchCoordinator: searchCoordinator
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    headerSection
                    searchSection
                    quickActionsSection
                    recentTicketsSection
                    permissionsSection
                    Spacer(minLength: ResponsiveDesign.spacing(20))
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Kundenservice")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
            .alert("Fehler", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "Ein Fehler ist aufgetreten")
            }
            .alert("Erfolg", isPresented: $viewModel.showSuccess) {
                Button("OK") { viewModel.clearSuccess() }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
            .sheet(item: $viewModel.selectedCustomer) { customer in
                CustomerDetailSheet(
                    customer: customer,
                    kycStatus: viewModel.customerKYCStatus,
                    investments: viewModel.customerInvestments,
                    documents: viewModel.customerDocuments,
                    viewModel: viewModel
                )
            }
            .sheet(isPresented: $viewModel.showCreateTicketSheet) {
                CreateTicketSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showKYCStatusList) {
                KYCStatusListView(viewModel: viewModel)
            }
            .sheet(item: $viewModel.selectedTicket) { ticket in
                TicketDetailSheet(ticket: ticket, viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showEscalateTicketSheet) {
                if let ticket = viewModel.ticketToEscalate {
                    EscalateTicketSheet(ticket: ticket, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $viewModel.showTicketQueueSheet) {
                TicketQueueView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showAssignTicketSheet) {
                if let ticket = viewModel.ticketForAction {
                    AssignTicketSheet(ticket: ticket, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $viewModel.showAnalyticsDashboard) {
                SupportAnalyticsDashboard(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showArchiveView) {
                TicketArchiveView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showTrendAlerts) {
                TrendAlertsView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showAgentPerformance) {
                AgentPerformanceDashboard(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showBulkOperations) {
                BulkOperationsView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showNotificationPreferences) {
                SupportNotificationPreferencesView(isCSR: true)
            }
            .sheet(isPresented: $viewModel.showEmailTemplates) {
                EmailTemplateEditorView()
            }
            .sheet(isPresented: $viewModel.showFAQKnowledgeBase) {
                FAQKnowledgeBaseView(
                    faqService: services.faqKnowledgeBaseService,
                    auditService: services.auditLoggingService,
                    isCSRMode: true,
                    userId: services.userService.currentUser?.id
                )
            }
            .sheet(isPresented: $viewModel.showSupportSettings) {
                CustomerSupportSettingsView()
            }
        }
    }

    // MARK: - Computed Properties

    private var unassignedTicketCount: Int {
        viewModel.supportTickets.filter { $0.assignedTo == nil && $0.status != .resolved && $0.status != .closed && $0.status != .archived }.count
    }

    /// Active tickets only (excludes resolved, closed, archived)
    private var activeTickets: [SupportTicket] {
        viewModel.supportTickets.filter { ticket in
            ticket.status != .resolved &&
            ticket.status != .closed &&
            ticket.status != .archived
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "headphones.circle.fill")
                    .font(ResponsiveDesign.titleFont())
                    .foregroundColor(AppTheme.accentLightBlue)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text("Kundenservice-Portal")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    Text("Kundendaten anzeigen und Support verwalten")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Spacer()
            }

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(AppTheme.accentGreen)

                Text("Alle Aktionen werden für Compliance-Zwecke protokolliert")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
            .padding(.top, ResponsiveDesign.spacing(4))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Search Section

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Kundensuche")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))

                TextField("Name, E-Mail oder Kundennummer...", text: $viewModel.searchQuery)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))

            if !viewModel.searchResults.isEmpty {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(viewModel.searchResults) { result in
                        CustomerSearchResultRow(result: result) {
                            Task {
                                await viewModel.selectCustomer(result)
                            }
                        }
                    }
                }
            } else if !viewModel.searchQuery.isEmpty && !viewModel.isSearching {
                Text("Keine Kunden gefunden")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding()
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Schnellaktionen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: ResponsiveDesign.spacing(12)) {
                QuickActionCard(
                    icon: "ticket.fill",
                    title: "Neues Ticket",
                    subtitle: "Support-Anfrage",
                    color: AppTheme.accentLightBlue,
                    isEnabled: viewModel.hasPermission(.createSupportTicket)
                ) {
                    viewModel.openCreateTicketSheet()
                }

                QuickActionCard(
                    icon: "person.fill.questionmark",
                    title: "KYC-Prüfung",
                    subtitle: "Status anzeigen",
                    color: AppTheme.accentGreen,
                    isEnabled: viewModel.hasPermission(.viewCustomerKYCStatus)
                ) {
                    viewModel.openKYCStatusList()
                }

                QuickActionCard(
                    icon: "tray.full.fill",
                    title: "Warteschlange",
                    subtitle: "Ticket-Zuweisung",
                    color: AppTheme.accentOrange,
                    isEnabled: viewModel.hasPermission(.respondToSupportTicket),
                    badge: unassignedTicketCount > 0 ? "\(unassignedTicketCount)" : nil
                ) {
                    viewModel.showTicketQueueSheet = true
                }

                QuickActionCard(
                    icon: "chart.bar.fill",
                    title: "Analytics",
                    subtitle: "Metriken & Berichte",
                    color: Color.purple,
                    isEnabled: viewModel.hasPermission(.viewCustomerSupportHistory)
                ) {
                    viewModel.showAnalyticsDashboard = true
                }

                QuickActionCard(
                    icon: "archivebox.fill",
                    title: "Archiv",
                    subtitle: "Geschlossene Tickets",
                    color: AppTheme.fontColor.opacity(0.6),
                    isEnabled: viewModel.hasPermission(.viewCustomerSupportHistory)
                ) {
                    viewModel.showArchiveView = true
                }

                QuickActionCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Trends",
                    subtitle: "Muster & Alerts",
                    color: AppTheme.accentRed,
                    isEnabled: viewModel.hasPermission(.viewCustomerSupportHistory),
                    badge: nil  // Could add trend count here
                ) {
                    viewModel.showTrendAlerts = true
                }

                QuickActionCard(
                    icon: "person.3.fill",
                    title: "Agent-Performance",
                    subtitle: "Team-Statistiken",
                    color: Color.cyan,
                    isEnabled: viewModel.hasPermission(.viewCustomerSupportHistory)
                ) {
                    viewModel.showAgentPerformance = true
                }

                QuickActionCard(
                    icon: "checkmark.rectangle.stack.fill",
                    title: "Massenbearbeitung",
                    subtitle: "Mehrere Tickets",
                    color: Color.indigo,
                    isEnabled: viewModel.hasPermission(.respondToSupportTicket)
                ) {
                    viewModel.showBulkOperations = true
                }

                QuickActionCard(
                    icon: "book.fill",
                    title: "FAQ Wissensdatenbank",
                    subtitle: "Artikel & Lösungen",
                    color: Color.mint,
                    isEnabled: viewModel.hasPermission(.viewCustomerSupportHistory)
                ) {
                    viewModel.showFAQKnowledgeBase = true
                }
            }

            // Admin Actions
            if viewModel.hasPermission(.viewCustomerSupportHistory) {
                Divider()
                    .padding(.vertical, ResponsiveDesign.spacing(8))

                Text("Einstellungen")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    SmallActionButton(
                        icon: "bell.badge.fill",
                        title: "Benachrichtigungen",
                        color: AppTheme.accentOrange
                    ) {
                        viewModel.showNotificationPreferences = true
                    }

                    SmallActionButton(
                        icon: "envelope.fill",
                        title: "E-Mail-Vorlagen",
                        color: AppTheme.accentLightBlue
                    ) {
                        viewModel.showEmailTemplates = true
                    }

                    SmallActionButton(
                        icon: "gear",
                        title: "Support-Einstellungen",
                        color: AppTheme.accentGreen
                    ) {
                        viewModel.showSupportSettings = true
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Recent Tickets Section

    private var recentTicketsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Aktuelle Tickets")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if activeTickets.isEmpty {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(ResponsiveDesign.largeTitleFont())
                        .foregroundColor(AppTheme.accentGreen.opacity(0.5))

                    Text("Keine aktiven Tickets")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    Text("Alle Tickets wurden bearbeitet")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ResponsiveDesign.spacing(20))
            } else {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(activeTickets.prefix(5)) { ticket in
                        TicketRow(ticket: ticket) {
                            viewModel.selectTicket(ticket)
                        }
                    }

                    // Show count if more tickets exist
                    if activeTickets.count > 5 {
                        Text("+ \(activeTickets.count - 5) weitere aktive Tickets")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.top, ResponsiveDesign.spacing(4))
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(AppTheme.accentOrange)

                Text("Meine Berechtigungen")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }

            // Show current CSR role
            if let csrRole = viewModel.currentCSRRole {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: csrRole.icon)
                        .font(ResponsiveDesign.iconFont())
                        .foregroundColor(csrRole.color)

                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                        Text("Aktuelle Rolle")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.tertiaryText)
                        Text(csrRole.displayName)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)
                    }

                    Spacer()

                    // Role badge
                    Text(csrRole.shortName)
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(csrRole.color)
                        .cornerRadius(8)
                }
                .padding()
                .background(csrRole.color.opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(8))
            }

            // Permissions by category
            ForEach(PermissionCategory.allCases, id: \.self) { category in
                if let permissions = viewModel.permissionsByCategory[category], !permissions.isEmpty {
                    PermissionCategoryRow(category: category, permissions: permissions)
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Preview

#Preview {
    CustomerSupportDashboardView()
        .environment(\.appServices, .live)
}





