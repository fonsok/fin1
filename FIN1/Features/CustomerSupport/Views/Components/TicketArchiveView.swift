import SwiftUI

// MARK: - Ticket Archive View
/// View for browsing archived/closed tickets

struct TicketArchiveView: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var archivedTickets: [SupportTicket] = []
    @State private var isLoading = false
    @State private var searchQuery = ""
    @State private var selectedFilter: ArchiveFilter = .all

    enum ArchiveFilter: String, CaseIterable {
        case all = "Alle"
        case archived = "Archiviert"
        case closed = "Geschlossen"
        case resolved = "Gelöst"

        var statusFilter: [SupportTicket.TicketStatus] {
            switch self {
            case .all: return [.archived, .closed, .resolved]
            case .archived: return [.archived]
            case .closed: return [.closed]
            case .resolved: return [.resolved]
            }
        }
    }

    private var filteredTickets: [SupportTicket] {
        var tickets = archivedTickets.filter { selectedFilter.statusFilter.contains($0.status) }

        if !searchQuery.isEmpty {
            tickets = tickets.filter {
                $0.ticketNumber.localizedCaseInsensitiveContains(searchQuery) ||
                $0.subject.localizedCaseInsensitiveContains(searchQuery) ||
                $0.customerName.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        return tickets
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                filterSection
                ticketList
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Archiv")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
            .task { await loadArchivedTickets() }
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))

                TextField("Ticket-Nr., Betreff oder Kunde...", text: $searchQuery)
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
                    ForEach(ArchiveFilter.allCases, id: \.rawValue) { filter in
                        FilterPill(
                            title: filter.rawValue,
                            isSelected: selectedFilter == filter,
                            count: archivedTickets.filter { filter.statusFilter.contains($0.status) }.count
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
            if isLoading {
                loadingView
            } else if filteredTickets.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: ResponsiveDesign.spacing(8)) {
                        ForEach(filteredTickets) { ticket in
                            ArchivedTicketRow(ticket: ticket) {
                                viewModel.selectTicket(ticket)
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
            Text("Lade Archiv...")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "archivebox")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.fontColor.opacity(0.3))

            Text("Keine archivierten Tickets")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Text("Geschlossene Tickets werden nach 30 Tagen automatisch archiviert.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadArchivedTickets() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let allTickets = try await viewModel.supportService.getSupportTickets(userId: nil)
            archivedTickets = allTickets.filter { ticket in
                ticket.status == .archived || ticket.status == .closed || ticket.status == .resolved
            }
            .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            viewModel.handleError(error)
        }
    }
}

// MARK: - Filter Pill

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Text(title)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(isSelected ? .bold : .regular)

                Text("\(count)")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : AppTheme.fontColor.opacity(0.1))
                    .cornerRadius(ResponsiveDesign.spacing(8))
            }
            .foregroundColor(isSelected ? .white : AppTheme.fontColor)
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .background(isSelected ? AppTheme.accentLightBlue : AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(20))
        }
    }
}

// MARK: - Archived Ticket Row

private struct ArchivedTicketRow: View {
    let ticket: SupportTicket
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    Text(ticket.ticketNumber)
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.accentLightBlue)

                    Spacer()

                    CSStatusBadge(text: ticket.status.displayName, color: statusColor)
                }

                Text(ticket.subject)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
                    .lineLimit(2)

                HStack {
                    Label(ticket.customerName, systemImage: "person.fill")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    Spacer()

                    if let closedAt = ticket.closedAt {
                        Text("Geschlossen: \(closedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }
                }

                // Reopen badge if within grace period
                if ticket.canReopen, let daysLeft = ticket.daysUntilReopenExpires {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(ResponsiveDesign.captionFont())
                        Text("Wiedereröffnung möglich (\(daysLeft) Tage)")
                            .font(ResponsiveDesign.captionFont())
                    }
                    .foregroundColor(AppTheme.accentOrange)
                    .padding(.top, ResponsiveDesign.spacing(4))
                }
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusColor: Color {
        switch ticket.status {
        case .archived: return AppTheme.fontColor.opacity(0.5)
        case .closed: return AppTheme.fontColor.opacity(0.6)
        case .resolved: return AppTheme.accentGreen
        default: return AppTheme.accentLightBlue
        }
    }
}

// MARK: - Preview

#Preview {
    TicketArchiveView(
        viewModel: CustomerSupportDashboardViewModel(
            supportService: AppServices.live.customerSupportService,
            auditService: AuditLoggingService(),
            searchCoordinator: CustomerSupportSearchCoordinator(supportService: AppServices.live.customerSupportService)
        )
    )
}

