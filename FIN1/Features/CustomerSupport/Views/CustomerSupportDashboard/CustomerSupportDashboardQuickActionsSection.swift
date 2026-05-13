import SwiftUI

/// Quick actions grid for CSR dashboard (tickets, KYC, queue, analytics, etc.).
struct CustomerSupportDashboardQuickActionsSection: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel

    private var unassignedTicketCount: Int {
        self.viewModel.supportTickets.filter { $0.assignedTo == nil && $0.status != .resolved && $0.status != .closed && $0.status != .archived }.count
    }

    var body: some View {
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
                    isEnabled: self.viewModel.hasPermission(.createSupportTicket)
                ) {
                    self.viewModel.openCreateTicketSheet()
                }

                QuickActionCard(
                    icon: "person.fill.questionmark",
                    title: "KYC-Prüfung",
                    subtitle: "Status anzeigen",
                    color: AppTheme.accentGreen,
                    isEnabled: self.viewModel.hasPermission(.viewCustomerKYCStatus)
                ) {
                    self.viewModel.openKYCStatusList()
                }

                QuickActionCard(
                    icon: "tray.full.fill",
                    title: "Warteschlange",
                    subtitle: "Ticket-Zuweisung",
                    color: AppTheme.accentOrange,
                    isEnabled: self.viewModel.hasPermission(.respondToSupportTicket),
                    badge: self.unassignedTicketCount > 0 ? "\(self.unassignedTicketCount)" : nil
                ) {
                    self.viewModel.showTicketQueueSheet = true
                }

                QuickActionCard(
                    icon: "chart.bar.fill",
                    title: "Analytics",
                    subtitle: "Metriken & Berichte",
                    color: Color.purple,
                    isEnabled: self.viewModel.hasPermission(.viewCustomerSupportHistory)
                ) {
                    self.viewModel.showAnalyticsDashboard = true
                }

                QuickActionCard(
                    icon: "archivebox.fill",
                    title: "Archiv",
                    subtitle: "Geschlossene Tickets",
                    color: AppTheme.fontColor.opacity(0.6),
                    isEnabled: self.viewModel.hasPermission(.viewCustomerSupportHistory)
                ) {
                    self.viewModel.showArchiveView = true
                }

                QuickActionCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Trends",
                    subtitle: "Muster & Alerts",
                    color: AppTheme.accentRed,
                    isEnabled: self.viewModel.hasPermission(.viewCustomerSupportHistory),
                    badge: nil
                ) {
                    self.viewModel.showTrendAlerts = true
                }

                QuickActionCard(
                    icon: "person.3.fill",
                    title: "Agent-Performance",
                    subtitle: "Team-Statistiken",
                    color: Color.cyan,
                    isEnabled: self.viewModel.hasPermission(.viewCustomerSupportHistory)
                ) {
                    self.viewModel.showAgentPerformance = true
                }

                QuickActionCard(
                    icon: "checkmark.rectangle.stack.fill",
                    title: "Massenbearbeitung",
                    subtitle: "Mehrere Tickets",
                    color: Color.indigo,
                    isEnabled: self.viewModel.hasPermission(.respondToSupportTicket)
                ) {
                    self.viewModel.showBulkOperations = true
                }

                QuickActionCard(
                    icon: "book.fill",
                    title: "FAQ Wissensdatenbank",
                    subtitle: "Artikel & Lösungen",
                    color: Color.mint,
                    isEnabled: self.viewModel.hasPermission(.viewCustomerSupportHistory)
                ) {
                    self.viewModel.showFAQKnowledgeBase = true
                }
            }

            if self.viewModel.hasPermission(.viewCustomerSupportHistory) {
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
                        self.viewModel.showNotificationPreferences = true
                    }

                    SmallActionButton(
                        icon: "envelope.fill",
                        title: "E-Mail-Vorlagen",
                        color: AppTheme.accentLightBlue
                    ) {
                        self.viewModel.showEmailTemplates = true
                    }

                    SmallActionButton(
                        icon: "gear",
                        title: "Support-Einstellungen",
                        color: AppTheme.accentGreen
                    ) {
                        self.viewModel.showSupportSettings = true
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}
