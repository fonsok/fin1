import SwiftUI

// MARK: - Ticket Queue View
/// Displays unassigned tickets waiting for manual assignment
/// Part of the round-robin with workload consideration system

struct TicketQueueView: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    queueStatsSection
                    agentWorkloadSection
                    unassignedTicketsSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Ticket-Warteschlange")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await viewModel.load() }
                    }, label: {
                        Image(systemName: "arrow.clockwise")
                    })
                }
            }
            .sheet(isPresented: $viewModel.showAssignTicketSheet) {
                if let ticket = viewModel.ticketForAction {
                    AssignTicketSheet(ticket: ticket, viewModel: viewModel)
                }
            }
        }
    }

    // MARK: - Queue Stats Section

    private var queueStatsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(AppTheme.accentLightBlue)
                Text("Übersicht")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }

            HStack(spacing: ResponsiveDesign.spacing(16)) {
                QueueStatCard(
                    title: "In Warteschlange",
                    value: "\(unassignedTickets.count)",
                    icon: "tray.full.fill",
                    color: unassignedTickets.isEmpty ? AppTheme.accentGreen : AppTheme.accentOrange
                )

                QueueStatCard(
                    title: "Agenten verfügbar",
                    value: "\(availableAgentsCount)/\(viewModel.availableAgents.count)",
                    icon: "person.2.fill",
                    color: availableAgentsCount > 0 ? AppTheme.accentGreen : AppTheme.accentRed
                )

                QueueStatCard(
                    title: "Ø Auslastung",
                    value: "\(Int(averageWorkload))%",
                    icon: "gauge.with.needle.fill",
                    color: averageWorkload < 60 ? AppTheme.accentGreen : averageWorkload < 80 ? AppTheme.accentOrange : AppTheme.accentRed
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Agent Workload Section

    private var agentWorkloadSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(AppTheme.accentLightBlue)
                Text("Agenten-Auslastung")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }

            ForEach(viewModel.availableAgents) { agent in
                AgentWorkloadRow(agent: agent)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Unassigned Tickets Section

    private var unassignedTicketsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "tray.fill")
                    .foregroundColor(AppTheme.accentOrange)
                Text("Unzugewiesene Tickets")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Text("\(unassignedTickets.count)")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(unassignedTickets.isEmpty ? AppTheme.accentGreen : AppTheme.accentOrange)
                    .cornerRadius(8)
            }

            if unassignedTickets.isEmpty {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(ResponsiveDesign.largeTitleFont())
                        .foregroundColor(AppTheme.accentGreen)
                    Text("Alle Tickets sind zugewiesen")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ResponsiveDesign.spacing(24))
            } else {
                ForEach(unassignedTickets) { ticket in
                    UnassignedTicketRow(ticket: ticket) {
                        viewModel.ticketForAction = ticket
                        viewModel.showAssignTicketSheet = true
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Computed Properties

    private var unassignedTickets: [SupportTicket] {
        viewModel.supportTickets.filter { $0.assignedTo == nil }
    }

    private var availableAgentsCount: Int {
        viewModel.availableAgents.filter { $0.canAcceptTickets }.count
    }

    private var averageWorkload: Double {
        guard !viewModel.availableAgents.isEmpty else { return 0 }
        let totalWorkload = viewModel.availableAgents.reduce(0.0) { $0 + $1.workloadPercentage }
        return totalWorkload / Double(viewModel.availableAgents.count)
    }
}

// MARK: - Queue Stat Card

private struct QueueStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            Image(systemName: icon)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(color)

            Text(value)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text(title)
                .font(.caption2)
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Agent Workload Row

private struct AgentWorkloadRow: View {
    let agent: CSRAgent

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            // Avatar
            ZStack {
                Circle()
                    .fill(agent.canAcceptTickets ? AppTheme.accentLightBlue.opacity(0.2) : AppTheme.fontColor.opacity(0.1))
                    .frame(width: 36, height: 36)

                Text(agent.name.prefix(2).uppercased())
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(agent.canAcceptTickets ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(agent.name)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)

                    if !agent.isAvailable {
                        Text("(offline)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }
                }

                Text(agent.specializations.prefix(2).joined(separator: ", "))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            // Workload bar
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(agent.currentTicketCount)/\(CSRAgent.maxTickets)")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(workloadColor)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.screenBackground)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(workloadColor)
                            .frame(width: geo.size.width * min(agent.workloadPercentage / 100, 1.0))
                    }
                }
                .frame(width: 60, height: 4)
            }
        }
        .padding(.vertical, ResponsiveDesign.spacing(4))
    }

    private var workloadColor: Color {
        if agent.workloadPercentage < 50 { return AppTheme.accentGreen }
        if agent.workloadPercentage < 80 { return AppTheme.accentOrange }
        return AppTheme.accentRed
    }
}

// MARK: - Unassigned Ticket Row

private struct UnassignedTicketRow: View {
    let ticket: SupportTicket
    let onAssign: () -> Void

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(ticket.ticketNumber)
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    CSStatusBadge(text: ticket.priority.displayName, color: priorityColor)
                }

                Text(ticket.subject)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                    .lineLimit(1)

                Text(ticket.customerName)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            }

            Spacer()

            // Time waiting
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeAgo(ticket.createdAt))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))

                Button(action: onAssign) {
                    Text("Zuweisen")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accentLightBlue)
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private var priorityColor: Color {
        switch ticket.priority {
        case .low: return AppTheme.accentGreen
        case .medium: return AppTheme.accentLightBlue
        case .high: return AppTheme.accentOrange
        case .urgent: return AppTheme.accentRed
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

