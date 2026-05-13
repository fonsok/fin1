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
                    self.queueStatsSection
                    self.agentWorkloadSection
                    self.unassignedTicketsSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Ticket-Warteschlange")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") { self.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await self.viewModel.load() }
                    }, label: {
                        Image(systemName: "arrow.clockwise")
                    })
                }
            }
            .sheet(isPresented: self.$viewModel.showAssignTicketSheet) {
                if let ticket = viewModel.ticketForAction {
                    AssignTicketSheet(ticket: ticket, viewModel: self.viewModel)
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
                    value: "\(self.unassignedTickets.count)",
                    icon: "tray.full.fill",
                    color: self.unassignedTickets.isEmpty ? AppTheme.accentGreen : AppTheme.accentOrange
                )

                QueueStatCard(
                    title: "Agenten verfügbar",
                    value: "\(self.availableAgentsCount)/\(self.viewModel.availableAgents.count)",
                    icon: "person.2.fill",
                    color: self.availableAgentsCount > 0 ? AppTheme.accentGreen : AppTheme.accentRed
                )

                QueueStatCard(
                    title: "Ø Auslastung",
                    value: "\(Int(self.averageWorkload))%",
                    icon: "gauge.with.needle.fill",
                    color: self.averageWorkload < 60 ? AppTheme.accentGreen : self.averageWorkload < 80 ? AppTheme.accentOrange : AppTheme.accentRed
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

            ForEach(self.viewModel.availableAgents) { agent in
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

                Text("\(self.unassignedTickets.count)")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, ResponsiveDesign.spacing(8))
                    .padding(.vertical, ResponsiveDesign.spacing(4))
                    .background(self.unassignedTickets.isEmpty ? AppTheme.accentGreen : AppTheme.accentOrange)
                    .cornerRadius(ResponsiveDesign.spacing(8))
            }

            if self.unassignedTickets.isEmpty {
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
                ForEach(self.unassignedTickets) { ticket in
                    UnassignedTicketRow(ticket: ticket) {
                        self.viewModel.ticketForAction = ticket
                        self.viewModel.showAssignTicketSheet = true
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
        self.viewModel.supportTickets.filter { $0.assignedTo == nil }
    }

    private var availableAgentsCount: Int {
        self.viewModel.availableAgents.filter { $0.canAcceptTickets }.count
    }

    private var averageWorkload: Double {
        guard !self.viewModel.availableAgents.isEmpty else { return 0 }
        let totalWorkload = self.viewModel.availableAgents.reduce(0.0) { $0 + $1.workloadPercentage }
        return totalWorkload / Double(self.viewModel.availableAgents.count)
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
            Image(systemName: self.icon)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(self.color)

            Text(self.value)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text(self.title)
                .font(ResponsiveDesign.captionFont())
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
                    .fill(self.agent.canAcceptTickets ? AppTheme.accentLightBlue.opacity(0.2) : AppTheme.fontColor.opacity(0.1))
                    .frame(width: 36, height: 36)

                Text(self.agent.name.prefix(2).uppercased())
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(self.agent.canAcceptTickets ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(self.agent.name)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)

                    if !self.agent.isAvailable {
                        Text("(offline)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }
                }

                Text(self.agent.specializations.prefix(2).joined(separator: ", "))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            // Workload bar
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(self.agent.currentTicketCount)/\(CSRAgent.maxTickets)")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(self.workloadColor)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
                            .fill(AppTheme.screenBackground)

                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
                            .fill(self.workloadColor)
                            .frame(width: geo.size.width * min(self.agent.workloadPercentage / 100, 1.0))
                    }
                }
                .frame(width: 60, height: 4)
            }
        }
        .padding(.vertical, ResponsiveDesign.spacing(4))
    }

    private var workloadColor: Color {
        if self.agent.workloadPercentage < 50 { return AppTheme.accentGreen }
        if self.agent.workloadPercentage < 80 { return AppTheme.accentOrange }
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
                .fill(self.priorityColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(self.ticket.ticketNumber)
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    CSStatusBadge(text: self.ticket.priority.displayName, color: self.priorityColor)
                }

                Text(self.ticket.subject)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                    .lineLimit(1)

                Text(self.ticket.customerName)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            }

            Spacer()

            // Time waiting
            VStack(alignment: .trailing, spacing: 2) {
                Text(self.timeAgo(self.ticket.createdAt))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))

                Button(action: self.onAssign) {
                    Text("Zuweisen")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                        .background(AppTheme.accentLightBlue)
                        .cornerRadius(ResponsiveDesign.spacing(6))
                }
            }
        }
        .padding()
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private var priorityColor: Color {
        switch self.ticket.priority {
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

