import SwiftUI

/// Filter section for 4-eyes approval queue (risk level chips).
struct FourEyesApprovalQueueFilterSection: View {
    @ObservedObject var viewModel: FourEyesApprovalQueueViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Filter")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    ApprovalFilterChip(
                        title: "Alle",
                        isSelected: self.viewModel.selectedFilter == nil,
                        action: { self.viewModel.selectedFilter = nil }
                    )
                    ForEach(ApprovalRiskLevel.allCases, id: \.self) { level in
                        ApprovalFilterChip(
                            title: level.displayName,
                            isSelected: self.viewModel.selectedFilter == level,
                            color: self.colorForRiskLevel(level),
                            action: { self.viewModel.selectedFilter = level }
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func colorForRiskLevel(_ level: ApprovalRiskLevel) -> Color {
        switch level {
        case .low: return AppTheme.accentGreen
        case .medium: return AppTheme.accentOrange
        case .high: return AppTheme.accentRed
        case .critical: return Color.purple
        }
    }
}
