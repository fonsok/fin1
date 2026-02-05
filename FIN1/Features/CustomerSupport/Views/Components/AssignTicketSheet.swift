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
                    ticketInfoSection
                    agentsSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle(ticket.assignedTo != nil ? "Ticket neu zuweisen" : "Ticket zuweisen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zuweisen") {
                        Task { await assignTicket() }
                    }
                    .disabled(selectedAgentId == nil || isSubmitting)
                }
            }
            .task {
                await loadAgents()
            }
            .alert("Fehler", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "Ein Fehler ist aufgetreten")
            }
            .overlay {
                if isSubmitting {
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
                Text(ticket.ticketNumber)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }

            Text(ticket.subject)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                CSStatusBadge(text: ticket.priority.displayName, color: priorityColor)
                CSStatusBadge(text: ticket.status.displayName, color: statusColor)
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

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if availableAgents.isEmpty {
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
                    ForEach(availableAgents) { agent in
                        AgentRow(
                            agent: agent,
                            isSelected: selectedAgentId == agent.id,
                            isCurrentAssignee: ticket.assignedTo == agent.id
                        ) {
                            selectedAgentId = agent.id
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
        switch ticket.priority {
        case .low: return AppTheme.accentGreen
        case .medium: return AppTheme.accentLightBlue
        case .high: return AppTheme.accentOrange
        case .urgent: return AppTheme.accentRed
        }
    }

    private var statusColor: Color {
        switch ticket.status {
        case .open, .inProgress: return AppTheme.accentLightBlue
        case .waitingForCustomer: return AppTheme.accentOrange
        case .escalated: return AppTheme.accentRed
        case .resolved, .closed: return AppTheme.accentGreen
        case .archived: return AppTheme.fontColor.opacity(0.5)
        }
    }

    private func loadAgents() async {
        isLoading = true
        defer { isLoading = false }
        availableAgents = await viewModel.getAvailableAgents()

        // Pre-select current assignee if exists
        if let currentAssignee = ticket.assignedTo {
            selectedAgentId = currentAssignee
        }
    }

    @MainActor
    private func assignTicket() async {
        guard let agentId = selectedAgentId else { return }

        // Don't reassign to same agent
        if ticket.assignedTo == agentId {
            dismiss()
            return
        }

        isSubmitting = true

        await viewModel.assignTicket(ticketId: ticket.id, to: agentId)

        // Reset submitting state
        isSubmitting = false

        // Dismiss if no error occurred
        if !viewModel.showError {
            viewModel.showAssignTicketSheet = false
            dismiss()
        }
    }
}

// MARK: - Agent Row

struct AgentRow: View {
    let agent: CSRAgent
    let isSelected: Bool
    let isCurrentAssignee: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(isSelected ? AppTheme.accentLightBlue : AppTheme.screenBackground)
                        .frame(width: 44, height: 44)

                    Text(agent.name.prefix(2).uppercased())
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : AppTheme.fontColor)
                }

                // Agent info
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    HStack {
                        Text(agent.name)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        if isCurrentAssignee {
                            Text("(aktuell)")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.accentGreen)
                        }
                    }

                    // Specializations
                    Text(agent.specializations.joined(separator: ", "))
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .lineLimit(1)

                    // Workload indicator
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        WorkloadIndicator(percentage: agent.workloadPercentage)
                        Text("\(agent.currentTicketCount)/\(CSRAgent.maxTickets) Tickets")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    }
                }

                Spacer()

                // Languages
                VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(2)) {
                    ForEach(agent.languages.prefix(2), id: \.self) { lang in
                        Text(lang)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }
                }

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
            .padding()
            .background(isSelected ? AppTheme.accentLightBlue.opacity(0.1) : AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(isSelected ? AppTheme.accentLightBlue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Workload Indicator

struct WorkloadIndicator: View {
    let percentage: Double

    private var color: Color {
        if percentage < 50 { return AppTheme.accentGreen }
        if percentage < 80 { return AppTheme.accentOrange }
        return AppTheme.accentRed
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
                    .fill(AppTheme.screenBackground)
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
                    .fill(color)
                    .frame(width: geo.size.width * min(percentage / 100, 1.0), height: 4)
            }
        }
        .frame(width: 40, height: 4)
    }
}

