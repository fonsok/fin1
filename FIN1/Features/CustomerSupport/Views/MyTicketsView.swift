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
        appServices.userService.currentUser?.id ?? ""
    }

    private var customerId: String {
        appServices.userService.currentUser?.customerId ?? ""
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
        var result = tickets

        // Apply status filter
        switch selectedFilter {
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
        if !searchQuery.isEmpty {
            result = result.filter {
                $0.ticketNumber.localizedCaseInsensitiveContains(searchQuery) ||
                $0.subject.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        return result.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var waitingForMeCount: Int {
        tickets.filter { $0.status == .waitingForCustomer }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                filterSection
                ticketList
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Meine Tickets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateTicket = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.accentLightBlue)
                    }
                }
            }
            .task { await loadTickets() }
            .refreshable { await loadTickets() }
            .sheet(item: $selectedTicket) { ticket in
                UserTicketDetailView(
                    ticket: ticket,
                    userId: userId,
                    supportService: appServices.customerSupportService
                )
            }
            .sheet(isPresented: $showCreateTicket) {
                ContactSupportView()
            }
            .alert("Fehler", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
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

                TextField("Ticket-Nr. oder Betreff...", text: $searchQuery)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                if !searchQuery.isEmpty {
                    Button { searchQuery = "" } label: {
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
                            isSelected: selectedFilter == filter,
                            badge: filter == .waitingForMe && waitingForMeCount > 0 ? waitingForMeCount : nil
                        ) {
                            selectedFilter = filter
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
            if isLoading && tickets.isEmpty {
                loadingView
            } else if filteredTickets.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: ResponsiveDesign.spacing(8)) {
                        ForEach(filteredTickets) { ticket in
                            MyTicketRow(ticket: ticket) {
                                selectedTicket = ticket
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
            Image(systemName: selectedFilter == .all ? "ticket" : "tray")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.fontColor.opacity(0.3))

            Text(emptyMessage)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            if selectedFilter == .all && tickets.isEmpty {
                Button {
                    showCreateTicket = true
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
        switch selectedFilter {
        case .all: return "Keine Tickets vorhanden"
        case .active: return "Keine aktiven Tickets"
        case .waitingForMe: return "Keine Tickets warten auf Sie"
        case .resolved: return "Keine gelösten Tickets"
        }
    }

    // MARK: - Actions

    private func loadTickets() async {
        isLoading = true
        defer { isLoading = false }

        do {
            tickets = try await appServices.customerSupportService.getSupportTickets(customerId: customerId)
        } catch {
            let appError = error.toAppError()
            errorMessage = appError.errorDescription ?? "An error occurred"
            showError = true
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
        Button(action: action) {
            HStack(spacing: ResponsiveDesign.spacing(6)) {
                Image(systemName: filter.icon)
                    .font(ResponsiveDesign.captionFont())

                Text(filter.rawValue)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(isSelected ? .semibold : .regular)

                if let badge = badge {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.accentRed)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                }
            }
            .foregroundColor(isSelected ? .white : AppTheme.fontColor)
            .padding(.horizontal, ResponsiveDesign.spacing(14))
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .background(isSelected ? AppTheme.accentLightBlue : AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(20))
        }
    }
}

// MARK: - My Ticket Row

private struct MyTicketRow: View {
    let ticket: SupportTicket
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                // Header
                HStack {
                    Text(ticket.ticketNumber)
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.accentLightBlue)

                    Spacer()

                    MyTicketStatusBadge(status: ticket.status)
                }

                // Subject
                Text(ticket.subject)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
                    .lineLimit(2)

                // Footer
                HStack {
                    // Date
                    Label(
                        ticket.updatedAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "clock"
                    )
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))

                    Spacer()

                    // Response count
                    if !ticket.responses.isEmpty {
                        Label("\(ticket.responses.count)", systemImage: "bubble.left.and.bubble.right")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    }

                    // Unread indicator
                    if hasUnreadResponse {
                        Circle()
                            .fill(AppTheme.accentRed)
                            .frame(width: 8, height: 8)
                    }
                }

                // Action required banner
                if ticket.status == .waitingForCustomer {
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
                        ticket.status == .waitingForCustomer ? AppTheme.accentOrange.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Check if there's a response newer than any customer response
    private var hasUnreadResponse: Bool {
        guard let lastAgentResponse = ticket.responses.last(where: { $0.agentId != ticket.customerId && !$0.isInternal }) else {
            return false
        }
        guard let lastCustomerResponse = ticket.responses.last(where: { $0.agentId == ticket.customerId }) else {
            return true  // Agent responded, customer never did
        }
        return lastAgentResponse.createdAt > lastCustomerResponse.createdAt
    }
}

// MARK: - My Ticket Status Badge

private struct MyTicketStatusBadge: View {
    let status: SupportTicket.TicketStatus

    var body: some View {
        Text(displayText)
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, ResponsiveDesign.spacing(8))
            .padding(.vertical, ResponsiveDesign.spacing(4))
            .background(statusColor)
            .cornerRadius(ResponsiveDesign.spacing(6))
    }

    private var displayText: String {
        switch status {
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
        switch status {
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

