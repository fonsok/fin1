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
                    self.headerSection
                    self.searchSection
                    CustomerSupportDashboardQuickActionsSection(viewModel: self.viewModel)
                    CustomerSupportDashboardRecentTicketsSection(viewModel: self.viewModel)
                    self.permissionsSection
                    Spacer(minLength: ResponsiveDesign.spacing(20))
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Kundenservice")
            .navigationBarTitleDisplayMode(.inline)
            .task { await self.viewModel.load() }
            .alert("Fehler", isPresented: self.$viewModel.showError) {
                Button("OK") { self.viewModel.clearError() }
            } message: {
                Text(self.viewModel.errorMessage ?? "Ein Fehler ist aufgetreten")
            }
            .alert("Erfolg", isPresented: self.$viewModel.showSuccess) {
                Button("OK") { self.viewModel.clearSuccess() }
            } message: {
                Text(self.viewModel.successMessage ?? "")
            }
            .sheet(item: self.$viewModel.selectedCustomer) { customer in
                CustomerDetailSheet(
                    customer: customer,
                    kycStatus: self.viewModel.customerKYCStatus,
                    investments: self.viewModel.customerInvestments,
                    documents: self.viewModel.customerDocuments,
                    viewModel: self.viewModel
                )
            }
            .sheet(isPresented: self.$viewModel.showCreateTicketSheet) {
                CreateTicketSheet(viewModel: self.viewModel)
            }
            .sheet(isPresented: self.$viewModel.showKYCStatusList) {
                KYCStatusListView(viewModel: self.viewModel)
            }
            .sheet(item: self.$viewModel.selectedTicket) { ticket in
                TicketDetailSheet(ticket: ticket, viewModel: self.viewModel)
            }
            .sheet(isPresented: self.$viewModel.showEscalateTicketSheet) {
                if let ticket = viewModel.ticketToEscalate {
                    EscalateTicketSheet(ticket: ticket, viewModel: self.viewModel)
                }
            }
            .sheet(isPresented: self.$viewModel.showTicketQueueSheet) {
                TicketQueueView(viewModel: self.viewModel)
            }
            .sheet(isPresented: self.$viewModel.showAssignTicketSheet) {
                if let ticket = viewModel.ticketForAction {
                    AssignTicketSheet(ticket: ticket, viewModel: self.viewModel)
                }
            }
            .sheet(isPresented: self.$viewModel.showAnalyticsDashboard) {
                SupportAnalyticsDashboard(viewModel: self.viewModel)
            }
            .sheet(isPresented: self.$viewModel.showArchiveView) {
                TicketArchiveView(viewModel: self.viewModel)
            }
            .sheet(isPresented: self.$viewModel.showTrendAlerts) {
                TrendAlertsView(viewModel: self.viewModel)
            }
            .sheet(isPresented: self.$viewModel.showAgentPerformance) {
                AgentPerformanceDashboard(viewModel: self.viewModel)
            }
            .sheet(isPresented: self.$viewModel.showBulkOperations) {
                BulkOperationsView(viewModel: self.viewModel)
            }
            .sheet(isPresented: self.$viewModel.showNotificationPreferences) {
                SupportNotificationPreferencesView(isCSR: true)
            }
            .sheet(isPresented: self.$viewModel.showEmailTemplates) {
                EmailTemplateEditorView()
            }
            .sheet(isPresented: self.$viewModel.showFAQKnowledgeBase) {
                FAQKnowledgeBaseView(
                    faqService: self.services.faqKnowledgeBaseService,
                    auditService: self.services.auditLoggingService,
                    isCSRMode: true,
                    userId: self.services.userService.currentUser?.id
                )
            }
            .sheet(isPresented: self.$viewModel.showSupportSettings) {
                CustomerSupportSettingsView()
            }
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

                TextField("Name, E-Mail oder Kundennummer...", text: self.$viewModel.searchQuery)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                if self.viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                if !self.viewModel.searchQuery.isEmpty {
                    Button(action: { self.viewModel.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))

            if !self.viewModel.searchResults.isEmpty {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(self.viewModel.searchResults) { result in
                        CustomerSearchResultRow(result: result) {
                            Task {
                                await self.viewModel.selectCustomer(result)
                            }
                        }
                    }
                }
            } else if !self.viewModel.searchQuery.isEmpty && !self.viewModel.isSearching {
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
                        .cornerRadius(ResponsiveDesign.spacing(8))
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





