import SwiftUI

// MARK: - Bulk Operations View
/// View for performing bulk actions on multiple tickets.
/// Subviews in BulkOperations/ (BulkSelectableTicketRow, PriorityBadge, BulkActionButton, BulkAssignSheet, BulkCloseSheet).
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
        self.viewModel.supportTickets.filter { ticket in
            ticket.status != .closed && ticket.status != .resolved && ticket.status != .archived
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                self.selectionHeader
                self.ticketList
                if !self.selectedTicketIds.isEmpty {
                    self.actionBar
                }
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Massenbearbeitung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { self.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(self.selectedTicketIds.count == self.selectableTickets.count ? "Keine" : "Alle") {
                        if self.selectedTicketIds.count == self.selectableTickets.count {
                            self.selectedTicketIds.removeAll()
                        } else {
                            self.selectedTicketIds = Set(self.selectableTickets.map { $0.id })
                        }
                    }
                }
            }
            .sheet(isPresented: self.$showAssignSheet) {
                BulkAssignSheet(
                    selectedCount: self.selectedTicketIds.count,
                    agents: self.viewModel.availableAgents
                ) { agentId in
                    Task { await self.bulkAssign(to: agentId) }
                }
            }
            .sheet(isPresented: self.$showCloseSheet) {
                BulkCloseSheet(selectedCount: self.selectedTicketIds.count) { reason in
                    Task { await self.bulkClose(reason: reason) }
                }
            }
        }
    }

    private var selectionHeader: some View {
        HStack {
            Image(systemName: self.selectedTicketIds.isEmpty ? "square" : "checkmark.square.fill")
                .foregroundColor(self.selectedTicketIds.isEmpty ? AppTheme.fontColor.opacity(0.5) : AppTheme.accentLightBlue)

            Text("\(self.selectedTicketIds.count) von \(self.selectableTickets.count) ausgewählt")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            Spacer()

            if !self.selectedTicketIds.isEmpty {
                Text("Tickets ausgewählt")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentLightBlue)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
    }

    private var ticketList: some View {
        ScrollView {
            LazyVStack(spacing: ResponsiveDesign.spacing(8)) {
                ForEach(self.selectableTickets) { ticket in
                    BulkSelectableTicketRow(
                        ticket: ticket,
                        isSelected: self.selectedTicketIds.contains(ticket.id)
                    ) {
                        self.toggleSelection(ticket.id)
                    }
                }

                if self.selectableTickets.isEmpty {
                    self.emptyState
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "tray")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
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

    private var actionBar: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Divider()

            if self.isProcessing {
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
                            self.showAssignSheet = true
                        }

                        BulkActionButton(
                            title: "Schließen",
                            icon: "xmark.circle.fill",
                            color: AppTheme.accentRed
                        ) {
                            self.showCloseSheet = true
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

    private func toggleSelection(_ ticketId: String) {
        if self.selectedTicketIds.contains(ticketId) {
            self.selectedTicketIds.remove(ticketId)
        } else {
            self.selectedTicketIds.insert(ticketId)
        }
    }

    private func bulkAssign(to agentId: String) async {
        self.isProcessing = true
        defer { isProcessing = false }

        var successCount = 0
        for ticketId in self.selectedTicketIds {
            do {
                try await self.viewModel.supportService.assignTicket(ticketId: ticketId, to: agentId)
                successCount += 1
            } catch {
                // Continue with other tickets
            }
        }

        await MainActor.run {
            self.showAssignSheet = false
            self.viewModel.showSuccessMessage("\(successCount) Tickets zugewiesen")
            self.selectedTicketIds.removeAll()
            Task { await self.viewModel.load() }
        }
    }

    private func bulkClose(reason: String) async {
        self.isProcessing = true
        defer { isProcessing = false }

        var successCount = 0
        for ticketId in self.selectedTicketIds {
            do {
                try await self.viewModel.supportService.closeTicket(ticketId: ticketId, closureReason: reason)
                successCount += 1
            } catch {
                // Continue with other tickets
            }
        }

        await MainActor.run {
            self.showCloseSheet = false
            self.viewModel.showSuccessMessage("\(successCount) Tickets geschlossen")
            self.selectedTicketIds.removeAll()
            Task { await self.viewModel.load() }
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
