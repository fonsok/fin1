import SwiftUI

// MARK: - Support Analytics Dashboard
/// Dashboard view for supervisors to view support metrics

struct SupportAnalyticsDashboard: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPeriod: MetricsPeriod = .week
    @State private var ticketMetrics: TicketMetrics = .empty
    @State private var agentMetrics: [AgentMetrics] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    periodSelector
                    if isLoading {
                        loadingView
                    } else {
                        overviewSection
                        statusBreakdownSection
                        agentPerformanceSection
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Support Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
            .task { await loadMetrics() }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                ForEach([MetricsPeriod.today, .week, .month, .quarter], id: \.rawValue) { period in
                    Button {
                        selectedPeriod = period
                        Task { await loadMetrics() }
                    } label: {
                        Text(period.rawValue)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(selectedPeriod == period ? .bold : .regular)
                            .foregroundColor(selectedPeriod == period ? .white : AppTheme.fontColor)
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            .background(selectedPeriod == period ? AppTheme.accentLightBlue : AppTheme.sectionBackground)
                            .cornerRadius(ResponsiveDesign.spacing(20))
                    }
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            ProgressView()
            Text("Lade Metriken...")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(40))
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Übersicht")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ResponsiveDesign.spacing(12)) {
                MetricCard(
                    title: "Tickets gesamt",
                    value: "\(ticketMetrics.totalTickets)",
                    icon: "ticket.fill",
                    color: AppTheme.accentLightBlue
                )
                MetricCard(
                    title: "Geschlossen",
                    value: "\(ticketMetrics.closedTickets)",
                    icon: "checkmark.circle.fill",
                    color: AppTheme.accentGreen
                )
                MetricCard(
                    title: "Ø Antwortzeit",
                    value: ticketMetrics.firstResponseTimeFormatted,
                    icon: "clock.fill",
                    color: AppTheme.accentOrange
                )
                MetricCard(
                    title: "Ø Lösungszeit",
                    value: ticketMetrics.resolutionTimeFormatted,
                    icon: "timer",
                    color: Color.purple
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Status Breakdown Section

    private var statusBreakdownSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Status-Verteilung")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                StatusBar(label: "Offen", count: ticketMetrics.openTickets, total: ticketMetrics.totalTickets, color: AppTheme.accentLightBlue)
                StatusBar(label: "In Bearbeitung", count: ticketMetrics.inProgressTickets, total: ticketMetrics.totalTickets, color: Color.cyan)
                StatusBar(label: "Wartet auf Kunde", count: ticketMetrics.waitingForCustomerTickets, total: ticketMetrics.totalTickets, color: AppTheme.accentOrange)
                StatusBar(label: "Eskaliert", count: ticketMetrics.escalatedTickets, total: ticketMetrics.totalTickets, color: AppTheme.accentRed)
                StatusBar(label: "Gelöst", count: ticketMetrics.resolvedTickets, total: ticketMetrics.totalTickets, color: AppTheme.accentGreen)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Agent Performance Section

    private var agentPerformanceSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Agent-Leistung")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            if agentMetrics.isEmpty {
                Text("Keine Agent-Daten verfügbar")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    .padding()
            } else {
                ForEach(agentMetrics) { agent in
                    AgentPerformanceRow(agent: agent)
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Actions

    private func loadMetrics() async {
        isLoading = true
        defer { isLoading = false }

        let dateRange = selectedPeriod.dateRange

        do {
            ticketMetrics = try await viewModel.supportService.getTicketMetrics(
                from: dateRange.start,
                to: dateRange.end
            )

            // Load all agent metrics
            var metrics: [AgentMetrics] = []
            let agents = try await viewModel.supportService.getAvailableAgents()
            for agent in agents {
                let agentMetric = try await viewModel.supportService.getAgentMetrics(
                    agentId: agent.id,
                    from: dateRange.start,
                    to: dateRange.end
                )
                metrics.append(agentMetric)
            }
            agentMetrics = metrics.sorted { $0.customerSatisfactionScore > $1.customerSatisfactionScore }
        } catch {
            viewModel.handleError(error)
        }
    }
}

// MARK: - Components
// Components extracted to AnalyticsDashboardComponents.swift:
// - MetricCard
// - StatusBar
// - AgentPerformanceRow
// - StatBadge

// MARK: - Preview

#Preview {
    SupportAnalyticsDashboard(
        viewModel: CustomerSupportDashboardViewModel(
            supportService: AppServices.live.customerSupportService,
            auditService: AuditLoggingService(),
            searchCoordinator: CustomerSupportSearchCoordinator(supportService: AppServices.live.customerSupportService)
        )
    )
}

