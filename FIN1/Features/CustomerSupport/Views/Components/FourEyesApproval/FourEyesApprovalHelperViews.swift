import SwiftUI

/// Stat card for 4-eyes dashboard (e.g. Ausstehend, Dringend).
struct ApprovalStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: self.icon)
                    .foregroundColor(self.color)
                Spacer()
            }
            Text(self.value)
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
            Text(self.title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .padding()
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }
}

/// Filter chip for approval queue (Alle, risk levels).
struct ApprovalFilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = AppTheme.accentLightBlue
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            Text(self.title)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(self.isSelected ? .semibold : .regular)
                .padding(.horizontal, ResponsiveDesign.spacing(12))
                .padding(.vertical, ResponsiveDesign.spacing(6))
                .background(self.isSelected ? self.color : AppTheme.screenBackground)
                .foregroundColor(self.isSelected ? .white : AppTheme.fontColor)
                .cornerRadius(ResponsiveDesign.spacing(16))
        }
    }
}

/// Label-value row for approval detail sheet.
struct ApprovalDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(self.label)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
            Spacer()
            Text(self.value)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
        }
    }
}
