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
            return trends.filter { $0.severity == severity }
        }
        return trends
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                headerSection
                severityFilter
                trendsList
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Trend-Analyse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await detectTrends() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
            .task { await detectTrends() }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Erkennt automatisch Muster und Anomalien in Support-Tickets für proaktive Maßnahmen. Beispiel: Wenn die Anzahl von Login-Problemen innerhalb einer Woche um 50% steigt, wird ein Warn-Trend erkannt und Sie erhalten Handlungsempfehlungen.")
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
                    count: trends.count,
                    isSelected: selectedSeverity == nil,
                    color: AppTheme.accentLightBlue
                ) {
                    selectedSeverity = nil
                }

                SeverityFilterButton(
                    title: "Kritisch",
                    count: trends.filter { $0.severity == .critical }.count,
                    isSelected: selectedSeverity == .critical,
                    color: AppTheme.accentRed
                ) {
                    selectedSeverity = .critical
                }

                SeverityFilterButton(
                    title: "Warnung",
                    count: trends.filter { $0.severity == .warning }.count,
                    isSelected: selectedSeverity == .warning,
                    color: AppTheme.accentOrange
                ) {
                    selectedSeverity = .warning
                }

                SeverityFilterButton(
                    title: "Info",
                    count: trends.filter { $0.severity == .info }.count,
                    isSelected: selectedSeverity == .info,
                    color: AppTheme.accentLightBlue
                ) {
                    selectedSeverity = .info
                }
            }
            .padding()
        }
        .background(AppTheme.sectionBackground)
    }

    // MARK: - Trends List

    private var trendsList: some View {
        Group {
            if isLoading {
                loadingView
            } else if filteredTrends.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                        ForEach(filteredTrends) { trend in
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
                .font(.system(size: ResponsiveDesign.iconSize() * 2))
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
        isLoading = true
        defer { isLoading = false }

        let trendService = TrendDetectionService()
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!

        do {
            let allTickets = try await viewModel.supportService.getSupportTickets(customerId: nil)

            let currentPeriod = allTickets.filter { $0.createdAt >= weekAgo }
            let previousPeriod = allTickets.filter { $0.createdAt >= twoWeeksAgo && $0.createdAt < weekAgo }

            trends = trendService.detectTrends(
                currentPeriodTickets: currentPeriod,
                previousPeriodTickets: previousPeriod,
                surveys: []
            )
            .sorted { $0.severity == .critical && $1.severity != .critical }
        } catch {
            viewModel.handleError(error)
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
        Button(action: action) {
            HStack(spacing: ResponsiveDesign.spacing(6)) {
                Text(title)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(isSelected ? .bold : .regular)

                if count > 0 {
                    Text("\(count)")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? color : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white : color)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                }
            }
            .foregroundColor(isSelected ? .white : AppTheme.fontColor)
            .padding(.horizontal, ResponsiveDesign.spacing(14))
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .background(isSelected ? color : AppTheme.screenBackground)
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
                Image(systemName: trend.type.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(severityColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(trend.type.displayName)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    Text(trend.title)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)
                }

                Spacer()

                SeverityBadge(severity: trend.severity)
            }

            // Description
            Text(trend.description)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            // Stats
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                TrendStatItem(icon: "ticket.fill", value: "\(trend.ticketCount)", label: "Tickets")
                TrendStatItem(icon: "person.2.fill", value: "\(trend.affectedCustomers)", label: "Kunden")

                if trend.percentageChange != 0 {
                    TrendStatItem(
                        icon: trend.percentageChange > 0 ? "arrow.up" : "arrow.down",
                        value: String(format: "%.0f%%", abs(trend.percentageChange)),
                        label: "Änderung"
                    )
                }
            }

            // Suggested Action
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppTheme.accentOrange)
                    .font(ResponsiveDesign.captionFont())

                Text(trend.suggestedAction)
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
                .stroke(severityColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var severityColor: Color {
        switch trend.severity {
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
        Text(severity.rawValue)
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, ResponsiveDesign.spacing(8))
            .padding(.vertical, ResponsiveDesign.spacing(4))
            .background(severityColor)
            .cornerRadius(ResponsiveDesign.spacing(6))
    }

    private var severityColor: Color {
        switch severity {
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
                Image(systemName: icon)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                Text(value)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }
            Text(label)
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

