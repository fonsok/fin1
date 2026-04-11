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
                    TicketDetailHeader(ticket: ticket)
                    TicketInfoSection(ticket: ticket)
                    TicketDescriptionSection(ticket: ticket)

                    if !ticket.responses.isEmpty {
                        TicketResponsesSection(responses: ticket.responses)
                    }

                    actionsSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Ticket Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.showRespondTicketSheet) {
                if let selectedTicket = viewModel.selectedTicket {
                    RespondTicketSheet(ticket: selectedTicket, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $viewModel.showAssignTicketSheet) {
                if let ticketForAction = viewModel.ticketForAction {
                    AssignTicketSheet(ticket: ticketForAction, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $viewModel.showResolveTicketSheet) {
                if let ticketForAction = viewModel.ticketForAction {
                    ResolveTicketSheet(ticket: ticketForAction, viewModel: viewModel)
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
                if ticket.status != .closed && ticket.status != .resolved {
                    actionButton(
                        icon: "bubble.left.fill",
                        title: "Antwort senden",
                        color: AppTheme.accentLightBlue
                    ) {
                        viewModel.showRespondTicketSheet = true
                    }
                }

                // Assign/Reassign Ticket
                if ticket.status != .closed && ticket.status != .resolved {
                    actionButton(
                        icon: ticket.assignedTo != nil ? "arrow.triangle.2.circlepath" : "person.badge.plus",
                        title: ticket.assignedTo != nil ? "Neu zuweisen" : "Zuweisen",
                        color: ticket.assignedTo != nil ? AppTheme.accentOrange : AppTheme.accentLightBlue
                    ) {
                        viewModel.ticketForAction = ticket
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showAssignTicketSheet = true
                        }
                    }
                }

                // Resolve Ticket
                if ticket.status == .inProgress || ticket.status == .waitingForCustomer {
                    actionButton(
                        icon: "checkmark.circle.fill",
                        title: "Ticket lösen",
                        color: AppTheme.accentGreen
                    ) {
                        viewModel.ticketForAction = ticket
                        viewModel.showResolveTicketSheet = true
                    }
                }

                // Close Ticket (after resolved)
                if ticket.status == .resolved {
                    actionButton(
                        icon: "xmark.circle.fill",
                        title: "Ticket schließen",
                        color: AppTheme.fontColor.opacity(0.6)
                    ) {
                        Task {
                            await viewModel.closeTicket(ticketId: ticket.id, closureReason: "Ticket gelöst und geschlossen")
                            dismiss()
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

#Preview {
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
