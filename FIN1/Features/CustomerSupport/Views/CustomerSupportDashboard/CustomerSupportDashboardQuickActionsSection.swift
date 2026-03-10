import SwiftUI

/// Quick actions grid for CSR dashboard (tickets, KYC, queue, analytics, etc.).
struct CustomerSupportDashboardQuickActionsSection: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel

    private var unassignedTicketCount: Int {
        viewModel.supportTickets.filter { $0.assignedTo == nil && $0.status != .resolved && $0.status != .closed && $0.status != .archived }.count
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
                    badge: nil
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
}
