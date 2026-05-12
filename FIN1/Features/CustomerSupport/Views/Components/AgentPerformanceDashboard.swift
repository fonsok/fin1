import SwiftUI

// MARK: - Agent Performance Dashboard

/// Dashboard showing individual CSR performance metrics
struct AgentPerformanceDashboard: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPeriod: MetricsPeriod = .week
    @State private var agentMetrics: [AgentMetrics] = []
    @State private var isLoading = false
    @State private var selectedAgent: CSRAgent?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    periodSelector
                    summarySection
                    agentRankingSection
                    if let agent = selectedAgent {
                        agentDetailSection(agent)
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Agent-Performance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
            .task(id: selectedPeriod) { await loadMetrics() }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                ForEach(MetricsPeriod.allCases, id: \.self) { period in
                    Button {
                        selectedPeriod = period
                    } label: {
                        Text(period.rawValue)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(selectedPeriod == period ? .semibold : .regular)
                            .foregroundColor(selectedPeriod == period ? .white : AppTheme.fontColor)
                            .padding(.horizontal, ResponsiveDesign.spacing(14))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            .background(selectedPeriod == period ? AppTheme.accentLightBlue : AppTheme.sectionBackground)
                            .cornerRadius(ResponsiveDesign.spacing(20))
                    }
                }
            }
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Team-Übersicht")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: ResponsiveDesign.spacing(12)) {
                AgentSummaryCard(
                    title: "Aktive Agents",
                    value: "\(viewModel.availableAgents.filter { $0.isAvailable }.count)",
                    icon: "person.fill.checkmark",
                    color: AppTheme.accentGreen
                )

                AgentSummaryCard(
                    title: "Durchschn. Auslastung",
                    value: String(format: "%.0f%%", averageWorkload),
                    icon: "chart.bar.fill",
                    color: workloadColor
                )

                AgentSummaryCard(
                    title: "Tickets bearbeitet",
                    value: "\(totalTicketsHandled)",
                    icon: "ticket.fill",
                    color: AppTheme.accentLightBlue
                )

                AgentSummaryCard(
                    title: "Durchschn. CSAT",
                    value: String(format: "%.1f", averageCSAT),
                    icon: "star.fill",
                    color: AppTheme.accentOrange
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Agent Ranking Section

    private var agentRankingSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Agent-Ranking")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if agentMetrics.isEmpty {
                Text("Keine Daten verfügbar")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(Array(sortedAgentMetrics.enumerated()), id: \.element.id) { index, metrics in
                    AgentRankingRow(
                        rank: index + 1,
                        metrics: metrics,
                        agent: viewModel.availableAgents.first { $0.id == metrics.id },
                        isSelected: selectedAgent?.id == metrics.id
                    ) {
                        withAnimation {
                            if selectedAgent?.id == metrics.id {
                                selectedAgent = nil
                            } else {
                                selectedAgent = viewModel.availableAgents.first { $0.id == metrics.id }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Agent Detail Section

    private func agentDetailSection(_ agent: CSRAgent) -> some View {
        let metrics = agentMetrics.first { $0.id == agent.id }

        return VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Details: \(agent.name)")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Button {
                    withAnimation { selectedAgent = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
            }

            // Specializations
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
                Text("Spezialisierungen")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                FlowLayout(spacing: 6) {
                    ForEach(agent.specializations, id: \.self) { spec in
                        Text(spec)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.accentLightBlue.opacity(0.1))
                            .cornerRadius(ResponsiveDesign.spacing(6))
                    }
                }
            }

            Divider()

            // Performance Metrics
            if let metrics = metrics {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: ResponsiveDesign.spacing(10)) {
                    AgentDetailMetric(label: "Tickets zugewiesen", value: "\(metrics.ticketsAssigned)")
                    AgentDetailMetric(label: "Tickets geschlossen", value: "\(metrics.ticketsClosed)")
                    AgentDetailMetric(label: "Eskaliert", value: "\(metrics.ticketsEscalated)")
                    AgentDetailMetric(label: "CSAT Score", value: String(format: "%.1f", metrics.customerSatisfactionScore))
                    AgentDetailMetric(label: "Ø Erste Antwort", value: formatHours(metrics.averageFirstResponseTime))
                    AgentDetailMetric(label: "Ø Lösungszeit", value: formatHours(metrics.averageResolutionTime))
                    AgentDetailMetric(label: "Positive Bewertungen", value: "\(metrics.positiveRatings)")
                    AgentDetailMetric(label: "Negative Bewertungen", value: "\(metrics.negativeRatings)")
                }
            }

            // Current Workload
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
                HStack {
                    Text("Aktuelle Auslastung")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    Spacer()

                    Text("\(agent.currentTicketCount)/\(CSRAgent.maxTickets) Tickets")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)
                }

                ProgressView(value: agent.workloadPercentage, total: 100)
                    .tint(workloadColorFor(agent.workloadPercentage))
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Computed Properties

    private var sortedAgentMetrics: [AgentMetrics] {
        agentMetrics.sorted { $0.ticketsClosed > $1.ticketsClosed }
    }

    private var averageWorkload: Double {
        let agents = viewModel.availableAgents
        guard !agents.isEmpty else { return 0 }
        return agents.reduce(0) { $0 + $1.workloadPercentage } / Double(agents.count)
    }

    private var workloadColor: Color {
        workloadColorFor(averageWorkload)
    }

    private func workloadColorFor(_ percentage: Double) -> Color {
        if percentage > 80 { return AppTheme.accentRed }
        if percentage > 60 { return AppTheme.accentOrange }
        return AppTheme.accentGreen
    }

    private var totalTicketsHandled: Int {
        agentMetrics.reduce(0) { $0 + $1.ticketsAssigned }
    }

    private var averageCSAT: Double {
        let scores = agentMetrics.filter { $0.surveysReceived > 0 }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0) { $0 + $1.customerSatisfactionScore } / Double(scores.count)
    }

    private func formatHours(_ hours: Double) -> String {
        if hours < 1 {
            return String(format: "%.0f Min.", hours * 60)
        } else if hours < 24 {
            return String(format: "%.1f Std.", hours)
        } else {
            return String(format: "%.1f Tage", hours / 24)
        }
    }

    // MARK: - Actions

    private func loadMetrics() async {
        isLoading = true
        defer { isLoading = false }

        let (startDate, endDate) = selectedPeriod.dateRange

        var metrics: [AgentMetrics] = []
        for agent in viewModel.availableAgents {
            do {
                let agentMetric = try await viewModel.supportService.getAgentMetrics(
                    agentId: agent.id,
                    from: startDate,
                    to: endDate
                )
                metrics.append(agentMetric)
            } catch {
                // Skip agents with errors
            }
        }
        agentMetrics = metrics
    }
}

// MARK: - Agent Summary Card

private struct AgentSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(ResponsiveDesign.captionFont())
                Spacer()
            }

            Text(value)
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text(title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .padding()
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }
}

// MARK: - Agent Ranking Row

private struct AgentRankingRow: View {
    let rank: Int
    let metrics: AgentMetrics
    let agent: CSRAgent?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 28, height: 28)

                    Text("\(rank)")
                        .font(ResponsiveDesign.scaledSystemFont(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }

                // Agent info
                VStack(alignment: .leading, spacing: 2) {
                    Text(metrics.agentName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    HStack(spacing: ResponsiveDesign.spacing(8)) {
                        Label("\(metrics.ticketsClosed)", systemImage: "checkmark.circle.fill")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentGreen)

                        if metrics.surveysReceived > 0 {
                            Label(String(format: "%.1f", metrics.customerSatisfactionScore), systemImage: "star.fill")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.accentOrange)
                        }
                    }
                }

                Spacer()

                // Workload indicator
                if let agent = agent {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(agent.currentTicketCount)/\(CSRAgent.maxTickets)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        Circle()
                            .fill(agent.isAvailable ? AppTheme.accentGreen : AppTheme.fontColor.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
            .padding()
            .background(isSelected ? AppTheme.accentLightBlue.opacity(0.1) : AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 1, green: 0.84, blue: 0) // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return AppTheme.fontColor.opacity(0.4)
        }
    }
}

// MARK: - Agent Detail Metric

private struct AgentDetailMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text(label)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Flow Layout for Tags

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    AgentPerformanceDashboard(
        viewModel: CustomerSupportDashboardViewModel(
            supportService: AppServices.live.customerSupportService,
            auditService: AuditLoggingService(),
            searchCoordinator: CustomerSupportSearchCoordinator(supportService: AppServices.live.customerSupportService)
        )
    )
}

