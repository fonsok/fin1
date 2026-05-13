import SwiftUI

// MARK: - SLA Badge

/// Compact badge showing SLA status
struct SLABadge: View {
    let slaInfo: SLAInfo
    let showTime: Bool

    init(slaInfo: SLAInfo, showTime: Bool = true) {
        self.slaInfo = slaInfo
        self.showTime = showTime
    }

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(4)) {
            Image(systemName: self.slaInfo.overallStatus.icon)
                .font(ResponsiveDesign.captionFont())

            if self.showTime, let timeString = slaInfo.formattedTimeRemaining {
                Text(timeString)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
            }
        }
        .foregroundColor(self.slaInfo.overallStatus.color)
        .padding(.horizontal, ResponsiveDesign.spacing(6))
        .padding(.vertical, ResponsiveDesign.spacing(3))
        .background(self.slaInfo.overallStatus.color.opacity(0.15))
        .cornerRadius(ResponsiveDesign.spacing(6))
    }
}

// MARK: - SLA Detail View

/// Detailed SLA information view
struct SLADetailView: View {
    let ticket: SupportTicket
    let config: SLAConfiguration

    init(ticket: SupportTicket, config: SLAConfiguration = .default) {
        self.ticket = ticket
        self.config = config
    }

    private var slaInfo: SLAInfo {
        self.ticket.getSLAInfo(config: self.config)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            // Header
            HStack {
                Image(systemName: "clock.badge.checkmark.fill")
                    .foregroundColor(AppTheme.accentLightBlue)

                Text("SLA Status")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                SLABadge(slaInfo: self.slaInfo)
            }

            Divider()

            // First Response SLA
            SLAMetricRow(
                title: "Erste Antwort",
                status: self.slaInfo.firstResponseStatus,
                deadline: self.slaInfo.firstResponseDeadline,
                timeRemaining: self.slaInfo.firstResponseTimeRemaining
            )

            // Resolution SLA
            SLAMetricRow(
                title: "Lösung",
                status: self.slaInfo.resolutionStatus,
                deadline: self.slaInfo.resolutionDeadline,
                timeRemaining: self.slaInfo.resolutionTimeRemaining
            )

            // Priority info
            HStack {
                Text("Priorität:")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Text(self.ticket.priority.rawValue)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(self.priorityColor)

                Spacer()

                Text("Ziel: \(Int(self.config.resolutionTargets[self.ticket.priority] ?? 72))h")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var priorityColor: Color {
        switch self.ticket.priority {
        case .urgent: return AppTheme.accentRed
        case .high: return AppTheme.accentOrange
        case .medium: return AppTheme.accentLightBlue
        case .low: return AppTheme.fontColor.opacity(0.6)
        }
    }
}

// MARK: - SLA Metric Row

private struct SLAMetricRow: View {
    let title: String
    let status: SLAStatus
    let deadline: Date?
    let timeRemaining: TimeInterval?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(self.title)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                if let deadline = deadline {
                    Text(deadline.formatted(date: .abbreviated, time: .shortened))
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
            }

            Spacer()

            HStack(spacing: ResponsiveDesign.spacing(6)) {
                Image(systemName: self.status.icon)
                    .foregroundColor(self.status.color)
                    .font(ResponsiveDesign.captionFont())

                if let remaining = timeRemaining {
                    Text(self.formatTimeRemaining(remaining))
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(self.status.color)
                } else {
                    Text(self.status.rawValue)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(self.status.color)
                }
            }
        }
    }

    private func formatTimeRemaining(_ time: TimeInterval) -> String {
        if time <= 0 {
            return "Überfällig"
        }

        let hours = Int(time / 3_600)
        let minutes = Int((time.truncatingRemainder(dividingBy: 3_600)) / 60)

        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - SLA Warning Banner

/// Banner shown when SLA is at risk
struct SLAWarningBanner: View {
    let slaInfo: SLAInfo

    var body: some View {
        if self.slaInfo.overallStatus == .warning || self.slaInfo.overallStatus == .breached {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: self.slaInfo.overallStatus == .breached ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(ResponsiveDesign.bodyFont())

                VStack(alignment: .leading, spacing: 2) {
                    Text(self.slaInfo.overallStatus == .breached ? "SLA überschritten!" : "SLA gefährdet")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.bold)

                    if let time = slaInfo.formattedTimeRemaining {
                        Text(self.slaInfo.overallStatus == .breached ? "Überfällig seit \(time)" : "Noch \(time)")
                            .font(ResponsiveDesign.captionFont())
                    }
                }

                Spacer()
            }
            .foregroundColor(.white)
            .padding()
            .background(self.slaInfo.overallStatus.color)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(20)) {
        // Create test tickets with different SLA statuses
        let urgentTicket = SupportTicket(
            id: "1",
            ticketNumber: "TKT-001",
            userId: "user:preview@test.com",
            customerName: "Test",
            subject: "Urgent",
            description: "Test",
            status: .open,
            priority: .urgent,
            assignedTo: nil,
            createdAt: Date().addingTimeInterval(-3_000),  // 50 min ago
            updatedAt: Date(),
            responses: []
        )

        SLABadge(slaInfo: urgentTicket.getSLAInfo())

        SLADetailView(ticket: urgentTicket)

        SLAWarningBanner(slaInfo: urgentTicket.getSLAInfo())
    }
    .padding()
    .background(AppTheme.screenBackground)
}

