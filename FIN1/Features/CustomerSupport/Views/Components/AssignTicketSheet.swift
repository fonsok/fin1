import SwiftUI

// MARK: - Assign Ticket Sheet
/// Sheet for assigning a ticket to a CSR agent

struct AssignTicketSheet: View {
    let ticket: SupportTicket
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var availableAgents: [CSRAgent] = []
    @State private var selectedAgentId: String?
    @State private var isLoading = true
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    self.ticketInfoSection
                    self.agentsSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle(self.ticket.assignedTo != nil ? "Ticket neu zuweisen" : "Ticket zuweisen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { self.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zuweisen") {
                        Task { await self.assignTicket() }
                    }
                    .disabled(self.selectedAgentId == nil || self.isSubmitting)
                }
            }
            .task {
                await self.loadAgents()
            }
            .alert("Fehler", isPresented: self.$viewModel.showError) {
                Button("OK") { self.viewModel.clearError() }
            } message: {
                Text(self.viewModel.errorMessage ?? "Ein Fehler ist aufgetreten")
            }
            .overlay {
                if self.isSubmitting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Wird zugewiesen...")
                                .padding()
                                .background(AppTheme.sectionBackground)
                                .cornerRadius(ResponsiveDesign.spacing(12))
                        }
                }
            }
        }
    }

    // MARK: - Ticket Info Section

    private var ticketInfoSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(AppTheme.accentLightBlue)
                Text(self.ticket.ticketNumber)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }

            Text(self.ticket.subject)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                CSStatusBadge(text: self.ticket.priority.displayName, color: self.priorityColor)
                CSStatusBadge(text: self.ticket.status.displayName, color: self.statusColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Agents Section

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Verfügbare Mitarbeiter")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            if self.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if self.availableAgents.isEmpty {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(ResponsiveDesign.largeTitleFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.3))
                    Text("Keine verfügbaren Mitarbeiter")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(self.availableAgents) { agent in
                        AgentRow(
                            agent: agent,
                            isSelected: self.selectedAgentId == agent.id,
                            isCurrentAssignee: self.ticket.assignedTo == agent.id
                        ) {
                            self.selectedAgentId = agent.id
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Helpers

    private var priorityColor: Color {
        switch self.ticket.priority {
        case .low: return AppTheme.accentGreen
        case .medium: return AppTheme.accentLightBlue
        case .high: return AppTheme.accentOrange
        case .urgent: return AppTheme.accentRed
        }
    }

    private var statusColor: Color {
        switch self.ticket.status {
        case .open, .inProgress: return AppTheme.accentLightBlue
        case .waitingForCustomer: return AppTheme.accentOrange
        case .escalated: return AppTheme.accentRed
        case .resolved, .closed: return AppTheme.accentGreen
        case .archived: return AppTheme.fontColor.opacity(0.5)
        }
    }

    private func loadAgents() async {
        self.isLoading = true
        defer { isLoading = false }
        self.availableAgents = await self.viewModel.getAvailableAgents()

        // Pre-select current assignee if exists
        if let currentAssignee = ticket.assignedTo {
            self.selectedAgentId = currentAssignee
        }
    }

    @MainActor
    private func assignTicket() async {
        guard let agentId = selectedAgentId else { return }

        // Don't reassign to same agent
        if self.ticket.assignedTo == agentId {
            self.dismiss()
            return
        }

        self.isSubmitting = true

        await self.viewModel.assignTicket(ticketId: self.ticket.id, to: agentId)

        // Reset submitting state
        self.isSubmitting = false

        // Dismiss if no error occurred
        if !self.viewModel.showError {
            self.viewModel.showAssignTicketSheet = false
            self.dismiss()
        }
    }
}

