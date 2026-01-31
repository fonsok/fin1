import SwiftUI

// MARK: - Bulk Operations View

/// View for performing bulk actions on multiple tickets
struct BulkOperationsView: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTicketIds: Set<String> = []
    @State private var showAssignSheet = false
    @State private var showCloseSheet = false
    @State private var showTagSheet = false
    @State private var isProcessing = false
    @State private var bulkAction: BulkAction?

    enum BulkAction: String {
        case assign = "Zuweisen"
        case close = "Schließen"
        case addTag = "Tag hinzufügen"
        case changePriority = "Priorität ändern"
    }

    private var selectableTickets: [SupportTicket] {
        viewModel.supportTickets.filter { ticket in
            ticket.status != .closed && ticket.status != .resolved && ticket.status != .archived
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                selectionHeader
                ticketList
                if !selectedTicketIds.isEmpty {
                    actionBar
                }
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Massenbearbeitung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(selectedTicketIds.count == selectableTickets.count ? "Keine" : "Alle") {
                        if selectedTicketIds.count == selectableTickets.count {
                            selectedTicketIds.removeAll()
                        } else {
                            selectedTicketIds = Set(selectableTickets.map { $0.id })
                        }
                    }
                }
            }
            .sheet(isPresented: $showAssignSheet) {
                BulkAssignSheet(
                    selectedCount: selectedTicketIds.count,
                    agents: viewModel.availableAgents
                ) { agentId in
                    Task { await bulkAssign(to: agentId) }
                }
            }
            .sheet(isPresented: $showCloseSheet) {
                BulkCloseSheet(selectedCount: selectedTicketIds.count) { reason in
                    Task { await bulkClose(reason: reason) }
                }
            }
        }
    }

    // MARK: - Selection Header

    private var selectionHeader: some View {
        HStack {
            Image(systemName: selectedTicketIds.isEmpty ? "square" : "checkmark.square.fill")
                .foregroundColor(selectedTicketIds.isEmpty ? AppTheme.fontColor.opacity(0.5) : AppTheme.accentLightBlue)

            Text("\(selectedTicketIds.count) von \(selectableTickets.count) ausgewählt")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            Spacer()

            if !selectedTicketIds.isEmpty {
                Text("Tickets ausgewählt")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentLightBlue)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
    }

    // MARK: - Ticket List

    private var ticketList: some View {
        ScrollView {
            LazyVStack(spacing: ResponsiveDesign.spacing(8)) {
                ForEach(selectableTickets) { ticket in
                    BulkSelectableTicketRow(
                        ticket: ticket,
                        isSelected: selectedTicketIds.contains(ticket.id)
                    ) {
                        toggleSelection(ticket.id)
                    }
                }

                if selectableTickets.isEmpty {
                    emptyState
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.fontColor.opacity(0.3))

            Text("Keine bearbeitbaren Tickets")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Text("Alle Tickets sind bereits geschlossen oder gelöst.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(40))
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Divider()

            if isProcessing {
                HStack {
                    ProgressView()
                    Text("Verarbeite...")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                }
                .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ResponsiveDesign.spacing(12)) {
                        BulkActionButton(
                            title: "Zuweisen",
                            icon: "person.badge.plus",
                            color: AppTheme.accentLightBlue
                        ) {
                            showAssignSheet = true
                        }

                        BulkActionButton(
                            title: "Schließen",
                            icon: "xmark.circle.fill",
                            color: AppTheme.accentRed
                        ) {
                            showCloseSheet = true
                        }

                        BulkActionButton(
                            title: "Priorität",
                            icon: "arrow.up.arrow.down",
                            color: AppTheme.accentOrange
                        ) {
                            // Show priority picker
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .background(AppTheme.sectionBackground)
    }

    // MARK: - Actions

    private func toggleSelection(_ ticketId: String) {
        if selectedTicketIds.contains(ticketId) {
            selectedTicketIds.remove(ticketId)
        } else {
            selectedTicketIds.insert(ticketId)
        }
    }

    private func bulkAssign(to agentId: String) async {
        isProcessing = true
        defer { isProcessing = false }

        var successCount = 0
        for ticketId in selectedTicketIds {
            do {
                try await viewModel.supportService.assignTicket(ticketId: ticketId, to: agentId)
                successCount += 1
            } catch {
                // Continue with other tickets
            }
        }

        await MainActor.run {
            showAssignSheet = false
            viewModel.showSuccessMessage("\(successCount) Tickets zugewiesen")
            selectedTicketIds.removeAll()
            Task { await viewModel.load() }
        }
    }

    private func bulkClose(reason: String) async {
        isProcessing = true
        defer { isProcessing = false }

        var successCount = 0
        for ticketId in selectedTicketIds {
            do {
                try await viewModel.supportService.closeTicket(ticketId: ticketId, closureReason: reason)
                successCount += 1
            } catch {
                // Continue with other tickets
            }
        }

        await MainActor.run {
            showCloseSheet = false
            viewModel.showSuccessMessage("\(successCount) Tickets geschlossen")
            selectedTicketIds.removeAll()
            Task { await viewModel.load() }
        }
    }
}

// MARK: - Bulk Selectable Ticket Row

private struct BulkSelectableTicketRow: View {
    let ticket: SupportTicket
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.4))
                    .font(.title3)

                // Ticket info
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    HStack {
                        Text(ticket.ticketNumber)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.accentLightBlue)

                        CSStatusBadge(text: ticket.status.displayName, color: statusColor)

                        PriorityBadge(priority: ticket.priority)
                    }

                    Text(ticket.subject)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .lineLimit(1)

                    Text(ticket.customerName)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Spacer()
            }
            .padding()
            .background(isSelected ? AppTheme.accentLightBlue.opacity(0.1) : AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(isSelected ? AppTheme.accentLightBlue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
}

// MARK: - Priority Badge

private struct PriorityBadge: View {
    let priority: SupportTicket.TicketPriority

    var body: some View {
        Text(priority.rawValue)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor)
            .cornerRadius(4)
    }

    private var priorityColor: Color {
        switch priority {
        case .urgent: return AppTheme.accentRed
        case .high: return AppTheme.accentOrange
        case .medium: return AppTheme.accentLightBlue
        case .low: return AppTheme.fontColor.opacity(0.5)
        }
    }
}

// MARK: - Bulk Action Button

private struct BulkActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ResponsiveDesign.spacing(6)) {
                Image(systemName: icon)
                    .font(ResponsiveDesign.captionFont())
                Text(title)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, ResponsiveDesign.spacing(16))
            .padding(.vertical, ResponsiveDesign.spacing(10))
            .background(color)
            .cornerRadius(ResponsiveDesign.spacing(20))
        }
    }
}

// MARK: - Bulk Assign Sheet

private struct BulkAssignSheet: View {
    let selectedCount: Int
    let agents: [CSRAgent]
    let onAssign: (String) -> Void

    @State private var selectedAgentId: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("\(selectedCount) Tickets zuweisen an:")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                ScrollView {
                    LazyVStack(spacing: ResponsiveDesign.spacing(8)) {
                        ForEach(agents.filter { $0.canAcceptTickets }) { agent in
                            Button {
                                selectedAgentId = agent.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(agent.name)
                                            .font(ResponsiveDesign.bodyFont())
                                            .foregroundColor(AppTheme.fontColor)

                                        Text("\(agent.currentTicketCount)/\(CSRAgent.maxTickets) Tickets")
                                            .font(ResponsiveDesign.captionFont())
                                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                                    }

                                    Spacer()

                                    Image(systemName: selectedAgentId == agent.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedAgentId == agent.id ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.3))
                                }
                                .padding()
                                .background(selectedAgentId == agent.id ? AppTheme.accentLightBlue.opacity(0.1) : AppTheme.sectionBackground)
                                .cornerRadius(ResponsiveDesign.spacing(10))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Agent auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zuweisen") {
                        if let agentId = selectedAgentId {
                            onAssign(agentId)
                        }
                    }
                    .disabled(selectedAgentId == nil)
                }
            }
        }
    }
}

// MARK: - Bulk Close Sheet

private struct BulkCloseSheet: View {
    let selectedCount: Int
    let onClose: (String) -> Void

    @State private var reason = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(ResponsiveDesign.largeTitleFont())
                    .foregroundColor(AppTheme.accentOrange)

                Text("\(selectedCount) Tickets schließen?")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Text("Diese Aktion kann nicht rückgängig gemacht werden.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    Text("Begründung")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    TextEditor(text: $reason)
                        .frame(minHeight: 100)
                        .padding(ResponsiveDesign.spacing(12))
                        .background(AppTheme.sectionBackground)
                        .cornerRadius(ResponsiveDesign.spacing(10))
                        .scrollContentBackground(.hidden)
                }
                .padding()

                Spacer()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Tickets schließen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        onClose(reason.isEmpty ? "Massenbearbeitung" : reason)
                    }
                    .foregroundColor(AppTheme.accentRed)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BulkOperationsView(
        viewModel: CustomerSupportDashboardViewModel(
            supportService: AppServices.live.customerSupportService,
            auditService: AuditLoggingService(),
            searchCoordinator: CustomerSupportSearchCoordinator(supportService: AppServices.live.customerSupportService)
        )
    )
}

