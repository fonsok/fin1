import SwiftUI

/// Card for a single 4-eyes approval request in the queue list.
struct ApprovalRequestCard: View {
    let request: FourEyesApprovalRequest
    let onTap: () -> Void

    var body: some View {
        Button(action: self.onTap) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    self.riskBadge
                    Spacer()
                    self.timeRemainingBadge
                }

                Text(self.request.requestType.displayName)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                if let customerName = request.customerName {
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Image(systemName: "person.fill")
                            .font(ResponsiveDesign.captionFont())
                        Text(customerName)
                    }
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Text(self.request.description)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .lineLimit(2)

                HStack {
                    Text("Angefordert von: \(self.request.requesterName)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.3))
                }
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var riskBadge: some View {
        let level = self.request.requestType.riskLevel
        return HStack(spacing: ResponsiveDesign.spacing(4)) {
            Circle()
                .fill(self.colorForRisk(level))
                .frame(width: 8, height: 8)
            Text(level.displayName)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(8))
        .padding(.vertical, ResponsiveDesign.spacing(4))
        .background(self.colorForRisk(level).opacity(0.15))
        .cornerRadius(ResponsiveDesign.spacing(6))
    }

    private var timeRemainingBadge: some View {
        Group {
            if let remaining = request.timeRemaining {
                let hours = Int(remaining / 3_600)
                let isUrgent = hours < 4

                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: "clock.fill")
                        .font(ResponsiveDesign.captionFont())
                    Text(hours > 0 ? "\(hours) Std." : "< 1 Std.")
                        .font(ResponsiveDesign.captionFont())
                }
                .foregroundColor(isUrgent ? AppTheme.accentRed : AppTheme.fontColor.opacity(0.7))
            }
        }
    }

    private func colorForRisk(_ level: ApprovalRiskLevel) -> Color {
        switch level {
        case .low: return AppTheme.accentGreen
        case .medium: return AppTheme.accentOrange
        case .high: return AppTheme.accentRed
        case .critical: return Color.purple
        }
    }
}
