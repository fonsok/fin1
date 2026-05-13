import SwiftUI

// MARK: - Ticket Detail Sheet
/// Sheet view for CSRs to view and manage support ticket details
/// Uses components from TicketDetailComponents.swift

struct TicketDetailSheet: View {
    let ticket: SupportTicket
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    TicketDetailHeader(ticket: self.ticket)
                    TicketInfoSection(ticket: self.ticket)
                    TicketDescriptionSection(ticket: self.ticket)

                    if !self.ticket.responses.isEmpty {
                        TicketResponsesSection(responses: self.ticket.responses)
                    }

                    self.actionsSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Ticket Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { self.dismiss() }
                }
            }
            .sheet(isPresented: self.$viewModel.showRespondTicketSheet) {
                if let selectedTicket = viewModel.selectedTicket {
                    RespondTicketSheet(ticket: selectedTicket, viewModel: self.viewModel)
                }
            }
            .sheet(isPresented: self.$viewModel.showAssignTicketSheet) {
                if let ticketForAction = viewModel.ticketForAction {
                    AssignTicketSheet(ticket: ticketForAction, viewModel: self.viewModel)
                }
            }
            .sheet(isPresented: self.$viewModel.showResolveTicketSheet) {
                if let ticketForAction = viewModel.ticketForAction {
                    ResolveTicketSheet(ticket: ticketForAction, viewModel: self.viewModel)
                }
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Aktionen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                // Respond to Ticket
                if self.ticket.status != .closed && self.ticket.status != .resolved {
                    self.actionButton(
                        icon: "bubble.left.fill",
                        title: "Antwort senden",
                        color: AppTheme.accentLightBlue
                    ) {
                        self.viewModel.showRespondTicketSheet = true
                    }
                }

                // Assign/Reassign Ticket
                if self.ticket.status != .closed && self.ticket.status != .resolved {
                    self.actionButton(
                        icon: self.ticket.assignedTo != nil ? "arrow.triangle.2.circlepath" : "person.badge.plus",
                        title: self.ticket.assignedTo != nil ? "Neu zuweisen" : "Zuweisen",
                        color: self.ticket.assignedTo != nil ? AppTheme.accentOrange : AppTheme.accentLightBlue
                    ) {
                        self.viewModel.ticketForAction = self.ticket
                        self.dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.viewModel.showAssignTicketSheet = true
                        }
                    }
                }

                // Resolve Ticket
                if self.ticket.status == .inProgress || self.ticket.status == .waitingForCustomer {
                    self.actionButton(
                        icon: "checkmark.circle.fill",
                        title: "Ticket lösen",
                        color: AppTheme.accentGreen
                    ) {
                        self.viewModel.ticketForAction = self.ticket
                        self.viewModel.showResolveTicketSheet = true
                    }
                }

                // Close Ticket (after resolved)
                if self.ticket.status == .resolved {
                    self.actionButton(
                        icon: "xmark.circle.fill",
                        title: "Ticket schließen",
                        color: AppTheme.fontColor.opacity(0.6)
                    ) {
                        Task {
                            await self.viewModel.closeTicket(ticketId: self.ticket.id, closureReason: "Ticket gelöst und geschlossen")
                            self.dismiss()
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview { @MainActor in
    let mockTicket = SupportTicket(
        id: "1",
        ticketNumber: "TKT-12345",
        userId: "user:preview@test.com",
        customerName: "Max Mustermann",
        subject: "Test Ticket",
        description: "This is a test ticket description.",
        status: .inProgress,
        priority: .medium,
        assignedTo: "user:csr1@test.com",
        createdAt: Date(),
        updatedAt: Date(),
        responses: []
    )

    // Use preview-compatible services
    let notificationService = NotificationService(documentService: DocumentService())
    let auditService = AuditLoggingService()
    let surveyService = SatisfactionSurveyService(notificationService: notificationService)

    let supportService = CustomerSupportService(
        auditService: auditService,
        userService: UserService(),
        notificationService: notificationService,
        satisfactionSurveyService: surveyService
    )

    let searchCoordinator = CustomerSupportSearchCoordinator(supportService: supportService)

    TicketDetailSheet(
        ticket: mockTicket,
        viewModel: CustomerSupportDashboardViewModel(
            supportService: supportService,
            auditService: auditService,
            searchCoordinator: searchCoordinator
        )
    )
}
