import SwiftUI

// MARK: - Trend Alerts View
/// View displaying detected trends and alerts for supervisors

struct TrendAlertsView: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var trends: [SupportTrend] = []
    @State private var isLoading = false
    @State private var selectedSeverity: SupportTrend.TrendSeverity?

    private var filteredTrends: [SupportTrend] {
        if let severity = selectedSeverity {
            return self.trends.filter { $0.severity == severity }
        }
        return self.trends
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                self.headerSection
                self.severityFilter
                self.trendsList
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Trend-Analyse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await self.detectTrends() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { self.dismiss() }
                }
            }
            .task { await self.detectTrends() }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(
                "Erkennt automatisch Muster und Anomalien in Support-Tickets für proaktive Maßnahmen. Beispiel: Wenn die Anzahl von Login-Problemen innerhalb einer Woche um 50% steigt, wird ein Warn-Trend erkannt und Sie erhalten Handlungsempfehlungen."
            )
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.sectionBackground)
    }

    // MARK: - Severity Filter

    private var severityFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                SeverityFilterButton(
                    title: "Alle",
                    count: self.trends.count,
                    isSelected: self.selectedSeverity == nil,
                    color: AppTheme.accentLightBlue
                ) {
                    self.selectedSeverity = nil
                }

                SeverityFilterButton(
                    title: "Kritisch",
                    count: self.trends.filter { $0.severity == .critical }.count,
                    isSelected: self.selectedSeverity == .critical,
                    color: AppTheme.accentRed
                ) {
                    self.selectedSeverity = .critical
                }

                SeverityFilterButton(
                    title: "Warnung",
                    count: self.trends.filter { $0.severity == .warning }.count,
                    isSelected: self.selectedSeverity == .warning,
                    color: AppTheme.accentOrange
                ) {
                    self.selectedSeverity = .warning
                }

                SeverityFilterButton(
                    title: "Info",
                    count: self.trends.filter { $0.severity == .info }.count,
                    isSelected: self.selectedSeverity == .info,
                    color: AppTheme.accentLightBlue
                ) {
                    self.selectedSeverity = .info
                }
            }
            .padding()
        }
        .background(AppTheme.sectionBackground)
    }

    // MARK: - Trends List

    private var trendsList: some View {
        Group {
            if self.isLoading {
                self.loadingView
            } else if self.filteredTrends.isEmpty {
                self.emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                        ForEach(self.filteredTrends) { trend in
                            TrendCard(trend: trend)
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
            Text("Analysiere Trends...")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "checkmark.seal.fill")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.accentGreen)

            Text("Keine auffälligen Trends")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text("Alle Support-Metriken sind im normalen Bereich.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func detectTrends() async {
        self.isLoading = true
        defer { isLoading = false }

        let trendService = TrendDetectionService()
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!

        do {
            let allTickets = try await viewModel.supportService.getSupportTickets(userId: nil)

            let currentPeriod = allTickets.filter { $0.createdAt >= weekAgo }
            let previousPeriod = allTickets.filter { $0.createdAt >= twoWeeksAgo && $0.createdAt < weekAgo }

            self.trends = trendService.detectTrends(
                currentPeriodTickets: currentPeriod,
                previousPeriodTickets: previousPeriod,
                surveys: []
            )
            .sorted { $0.severity == .critical && $1.severity != .critical }
        } catch {
            self.viewModel.handleError(error)
        }
    }
}

// MARK: - Severity Filter Button

private struct SeverityFilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: ResponsiveDesign.spacing(6)) {
                Text(self.title)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(self.isSelected ? .bold : .regular)

                if self.count > 0 {
                    Text("\(self.count)")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.bold)
                        .foregroundColor(self.isSelected ? self.color : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(self.isSelected ? Color.white : self.color)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                }
            }
            .foregroundColor(self.isSelected ? .white : AppTheme.fontColor)
            .padding(.horizontal, ResponsiveDesign.spacing(14))
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .background(self.isSelected ? self.color : AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(20))
        }
    }
}

// MARK: - Trend Card

private struct TrendCard: View {
    let trend: SupportTrend

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            // Header
            HStack {
                Image(systemName: self.trend.type.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(self.severityColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(self.trend.type.displayName)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    Text(self.trend.title)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)
                }

                Spacer()

                SeverityBadge(severity: self.trend.severity)
            }

            // Description
            Text(self.trend.description)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            // Stats
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                TrendStatItem(icon: "ticket.fill", value: "\(self.trend.ticketCount)", label: "Tickets")
                TrendStatItem(icon: "person.2.fill", value: "\(self.trend.affectedCustomers)", label: "Kunden")

                if self.trend.percentageChange != 0 {
                    TrendStatItem(
                        icon: self.trend.percentageChange > 0 ? "arrow.up" : "arrow.down",
                        value: String(format: "%.0f%%", abs(self.trend.percentageChange)),
                        label: "Änderung"
                    )
                }
            }

            // Suggested Action
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppTheme.accentOrange)
                    .font(ResponsiveDesign.captionFont())

                Text(self.trend.suggestedAction)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
            .padding()
            .background(AppTheme.accentOrange.opacity(0.1))
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .stroke(self.severityColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var severityColor: Color {
        switch self.trend.severity {
        case .critical: return AppTheme.accentRed
        case .warning: return AppTheme.accentOrange
        case .info: return AppTheme.accentLightBlue
        }
    }
}

// MARK: - Severity Badge

private struct SeverityBadge: View {
    let severity: SupportTrend.TrendSeverity

    var body: some View {
        Text(self.severity.rawValue)
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, ResponsiveDesign.spacing(8))
            .padding(.vertical, ResponsiveDesign.spacing(4))
            .background(self.severityColor)
            .cornerRadius(ResponsiveDesign.spacing(6))
    }

    private var severityColor: Color {
        switch self.severity {
        case .critical: return AppTheme.accentRed
        case .warning: return AppTheme.accentOrange
        case .info: return AppTheme.accentLightBlue
        }
    }
}

// MARK: - Trend Stat Item

private struct TrendStatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(2)) {
            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Image(systemName: self.icon)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                Text(self.value)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }
            Text(self.label)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.5))
        }
    }
}

// MARK: - Preview

#Preview {
    TrendAlertsView(
        viewModel: CustomerSupportDashboardViewModel(
            supportService: AppServices.live.customerSupportService,
            auditService: AuditLoggingService(),
            searchCoordinator: CustomerSupportSearchCoordinator(supportService: AppServices.live.customerSupportService)
        )
    )
}

