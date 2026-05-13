import SwiftUI

// MARK: - My Tickets View

/// Customer-facing view for managing their support tickets
struct MyTicketsView: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.dismiss) private var dismiss

    @State private var tickets: [SupportTicket] = []
    @State private var isLoading = false
    @State private var searchQuery = ""
    @State private var selectedFilter: TicketFilter = .active
    @State private var selectedTicket: SupportTicket?
    @State private var showCreateTicket = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var userId: String {
        self.appServices.userService.currentUser?.id ?? ""
    }

    private var endUserObjectId: String {
        self.appServices.userService.currentUser?.id ?? ""
    }

    enum TicketFilter: String, CaseIterable {
        case all = "Alle"
        case active = "Aktiv"
        case waitingForMe = "Warte auf mich"
        case resolved = "Gelöst"

        var icon: String {
            switch self {
            case .all: return "tray.full.fill"
            case .active: return "clock.fill"
            case .waitingForMe: return "exclamationmark.bubble.fill"
            case .resolved: return "checkmark.circle.fill"
            }
        }
    }

    private var filteredTickets: [SupportTicket] {
        var result = self.tickets

        // Apply status filter
        switch self.selectedFilter {
        case .all:
            break
        case .active:
            result = result.filter { $0.status == .open || $0.status == .inProgress }
        case .waitingForMe:
            result = result.filter { $0.status == .waitingForCustomer }
        case .resolved:
            result = result.filter { $0.status == .resolved || $0.status == .closed }
        }

        // Apply search
        if !self.searchQuery.isEmpty {
            result = result.filter {
                $0.ticketNumber.localizedCaseInsensitiveContains(self.searchQuery) ||
                    $0.subject.localizedCaseInsensitiveContains(self.searchQuery)
            }
        }

        return result.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var waitingForMeCount: Int {
        self.tickets.filter { $0.status == .waitingForCustomer }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                self.filterSection
                self.ticketList
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Meine Tickets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") { self.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        self.showCreateTicket = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.accentLightBlue)
                    }
                }
            }
            .task { await self.loadTickets() }
            .refreshable { await self.loadTickets() }
            .sheet(item: self.$selectedTicket) { ticket in
                UserTicketDetailView(
                    ticket: ticket,
                    userId: self.userId,
                    supportService: self.appServices.customerSupportService
                )
            }
            .sheet(isPresented: self.$showCreateTicket) {
                ContactSupportView()
            }
            .alert("Fehler", isPresented: self.$showError) {
                Button("OK") {}
            } message: {
                Text(self.errorMessage)
            }
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))

                TextField("Ticket-Nr. oder Betreff...", text: self.$searchQuery)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                if !self.searchQuery.isEmpty {
                    Button { self.searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))

            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(TicketFilter.allCases, id: \.rawValue) { filter in
                        MyTicketFilterPill(
                            filter: filter,
                            isSelected: self.selectedFilter == filter,
                            badge: filter == .waitingForMe && self.waitingForMeCount > 0 ? self.waitingForMeCount : nil
                        ) {
                            self.selectedFilter = filter
                        }
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Ticket List

    private var ticketList: some View {
        Group {
            if self.isLoading && self.tickets.isEmpty {
                self.loadingView
            } else if self.filteredTickets.isEmpty {
                self.emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: ResponsiveDesign.spacing(8)) {
                        ForEach(self.filteredTickets) { ticket in
                            MyTicketRow(ticket: ticket) {
                                self.selectedTicket = ticket
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            ProgressView()
            Text("Lade Tickets...")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: self.selectedFilter == .all ? "ticket" : "tray")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.fontColor.opacity(0.3))

            Text(self.emptyMessage)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            if self.selectedFilter == .all && self.tickets.isEmpty {
                Button {
                    self.showCreateTicket = true
                } label: {
                    Label("Neues Ticket erstellen", systemImage: "plus.circle.fill")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.white)
                        .padding()
                        .background(AppTheme.accentLightBlue)
                        .cornerRadius(ResponsiveDesign.spacing(10))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyMessage: String {
        switch self.selectedFilter {
        case .all: return "Keine Tickets vorhanden"
        case .active: return "Keine aktiven Tickets"
        case .waitingForMe: return "Keine Tickets warten auf Sie"
        case .resolved: return "Keine gelösten Tickets"
        }
    }

    // MARK: - Actions

    private func loadTickets() async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            self.tickets = try await self.appServices.customerSupportService.getSupportTickets(userId: self.endUserObjectId)
        } catch {
            let appError = error.toAppError()
            self.errorMessage = appError.errorDescription ?? "An error occurred"
            self.showError = true
        }
    }
}

// MARK: - My Ticket Filter Pill

private struct MyTicketFilterPill: View {
    let filter: MyTicketsView.TicketFilter
    let isSelected: Bool
    let badge: Int?
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: ResponsiveDesign.spacing(6)) {
                Image(systemName: self.filter.icon)
                    .font(ResponsiveDesign.captionFont())

                Text(self.filter.rawValue)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(self.isSelected ? .semibold : .regular)

                if let badge = badge {
                    Text("\(badge)")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, ResponsiveDesign.spacing(6))
                        .padding(.vertical, ResponsiveDesign.spacing(2))
                        .background(AppTheme.accentRed)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                }
            }
            .foregroundColor(self.isSelected ? .white : AppTheme.fontColor)
            .padding(.horizontal, ResponsiveDesign.spacing(14))
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .background(self.isSelected ? AppTheme.accentLightBlue : AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(20))
        }
    }
}

// MARK: - My Ticket Row

private struct MyTicketRow: View {
    let ticket: SupportTicket
    let onTap: () -> Void

    var body: some View {
        Button(action: self.onTap) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                // Header
                HStack {
                    Text(self.ticket.ticketNumber)
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.accentLightBlue)

                    Spacer()

                    MyTicketStatusBadge(status: self.ticket.status)
                }

                // Subject
                Text(self.ticket.subject)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
                    .lineLimit(2)

                // Footer
                HStack {
                    // Date
                    Label(
                        self.ticket.updatedAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "clock"
                    )
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))

                    Spacer()

                    // Response count
                    if !self.ticket.responses.isEmpty {
                        Label("\(self.ticket.responses.count)", systemImage: "bubble.left.and.bubble.right")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    }

                    // Unread indicator
                    if self.hasUnreadResponse {
                        Circle()
                            .fill(AppTheme.accentRed)
                            .frame(width: 8, height: 8)
                    }
                }

                // Action required banner
                if self.ticket.status == .waitingForCustomer {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(ResponsiveDesign.captionFont())
                        Text("Ihre Rückmeldung wird benötigt")
                            .font(ResponsiveDesign.captionFont())
                    }
                    .foregroundColor(AppTheme.accentOrange)
                    .padding(.top, ResponsiveDesign.spacing(4))
                }
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(
                        self.ticket.status == .waitingForCustomer ? AppTheme.accentOrange.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Check if there's a response newer than any customer response
    private var hasUnreadResponse: Bool {
        guard let lastAgentResponse = ticket.responses.last(where: { $0.agentId != ticket.userId && !$0.isInternal }) else {
            return false
        }
        guard let lastCustomerResponse = ticket.responses.last(where: { $0.agentId == ticket.userId }) else {
            return true  // Agent responded, customer never did
        }
        return lastAgentResponse.createdAt > lastCustomerResponse.createdAt
    }
}

// MARK: - My Ticket Status Badge

private struct MyTicketStatusBadge: View {
    let status: SupportTicket.TicketStatus

    var body: some View {
        Text(self.displayText)
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, ResponsiveDesign.spacing(8))
            .padding(.vertical, ResponsiveDesign.spacing(4))
            .background(self.statusColor)
            .cornerRadius(ResponsiveDesign.spacing(6))
    }

    private var displayText: String {
        switch self.status {
        case .open: return "Offen"
        case .inProgress: return "In Bearbeitung"
        case .waitingForCustomer: return "Warte auf Sie"
        case .escalated: return "Eskaliert"
        case .resolved: return "Gelöst"
        case .closed: return "Geschlossen"
        case .archived: return "Archiviert"
        }
    }

    private var statusColor: Color {
        switch self.status {
        case .open: return AppTheme.accentLightBlue
        case .inProgress: return AppTheme.accentLightBlue
        case .waitingForCustomer: return AppTheme.accentOrange
        case .escalated: return AppTheme.accentRed
        case .resolved: return AppTheme.accentGreen
        case .closed: return AppTheme.fontColor.opacity(0.5)
        case .archived: return AppTheme.fontColor.opacity(0.3)
        }
    }
}

// MARK: - Preview

#Preview {
    MyTicketsView()
        .environment(\.appServices, .live)
}

