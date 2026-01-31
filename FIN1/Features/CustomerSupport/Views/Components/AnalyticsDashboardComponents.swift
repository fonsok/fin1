import SwiftUI

// MARK: - Analytics Dashboard Components
/// Extracted components for SupportAnalyticsDashboard

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
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

// MARK: - Status Bar

struct StatusBar: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            HStack {
                Text(label)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
                Text("\(count)")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppTheme.fontColor.opacity(0.1))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Agent Performance Row

struct AgentPerformanceRow: View {
    let agent: AgentMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(performanceLevelColor)

                Text(agent.agentName)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(ResponsiveDesign.captionFont())
                    Text(String(format: "%.1f", agent.customerSatisfactionScore))
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)
                }
            }

            HStack(spacing: ResponsiveDesign.spacing(16)) {
                StatBadge(icon: "ticket.fill", value: "\(agent.ticketsAssigned)", label: "Zugewiesen")
                StatBadge(icon: "checkmark.circle.fill", value: "\(agent.ticketsClosed)", label: "Geschlossen")
                StatBadge(icon: "clock.fill", value: formatHours(agent.averageResolutionTime), label: "Ø Zeit")
            }

            CSStatusBadge(text: agent.performanceLevel.rawValue, color: performanceLevelColor)
        }
        .padding()
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private var performanceLevelColor: Color {
        switch agent.performanceLevel {
        case .excellent: return AppTheme.accentGreen
        case .good: return Color.cyan
        case .average: return AppTheme.accentOrange
        case .needsImprovement: return AppTheme.accentRed
        }
    }

    private func formatHours(_ hours: Double) -> String {
        if hours < 1 { return String(format: "%.0fmin", hours * 60) }
        if hours < 24 { return String(format: "%.1fh", hours) }
        return String(format: "%.1fd", hours / 24)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                Text(value)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.fontColor.opacity(0.5))
        }
    }
}

