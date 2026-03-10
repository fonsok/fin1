import SwiftUI

/// Stats overview section for 4-eyes approval queue.
struct FourEyesApprovalQueueStatsSection: View {
    let statistics: ApprovalQueueStats?

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "eye.2.fill")
                    .foregroundColor(AppTheme.accentLightBlue)
                Text("4-Augen-Prinzip Übersicht")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }

            if let stats = statistics {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: ResponsiveDesign.spacing(12)) {
                    ApprovalStatCard(
                        title: "Ausstehend",
                        value: "\(stats.pendingCount)",
                        icon: "hourglass",
                        color: AppTheme.accentOrange
                    )
                    ApprovalStatCard(
                        title: "Dringend",
                        value: "\(stats.urgentRequests)",
                        icon: "exclamationmark.triangle.fill",
                        color: AppTheme.accentRed
                    )
                    ApprovalStatCard(
                        title: "Genehmigt heute",
                        value: "\(stats.approvedToday)",
                        icon: "checkmark.circle.fill",
                        color: AppTheme.accentGreen
                    )
                    ApprovalStatCard(
                        title: "Ø Bearbeitungszeit",
                        value: String(format: "%.1f Std.", stats.averageApprovalTimeHours),
                        icon: "clock.fill",
                        color: AppTheme.accentLightBlue
                    )
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}
