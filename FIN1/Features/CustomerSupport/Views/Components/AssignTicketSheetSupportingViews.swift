import SwiftUI

// MARK: - Agent Row

struct AgentRow: View {
    let agent: CSRAgent
    let isSelected: Bool
    let isCurrentAssignee: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: self.onTap) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                ZStack {
                    Circle()
                        .fill(self.isSelected ? AppTheme.accentLightBlue : AppTheme.screenBackground)
                        .frame(width: 44, height: 44)

                    Text(self.agent.name.prefix(2).uppercased())
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(self.isSelected ? .white : AppTheme.fontColor)
                }

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    HStack {
                        Text(self.agent.name)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        if self.isCurrentAssignee {
                            Text("(aktuell)")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.accentGreen)
                        }
                    }

                    Text(self.agent.specializations.joined(separator: ", "))
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .lineLimit(1)

                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        WorkloadIndicator(percentage: self.agent.workloadPercentage)
                        Text("\(self.agent.currentTicketCount)/\(CSRAgent.maxTickets) Tickets")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(2)) {
                    ForEach(self.agent.languages.prefix(2), id: \.self) { lang in
                        Text(lang)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }
                }

                if self.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
            .padding()
            .background(self.isSelected ? AppTheme.accentLightBlue.opacity(0.1) : AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(self.isSelected ? AppTheme.accentLightBlue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Workload Indicator

struct WorkloadIndicator: View {
    let percentage: Double

    private var color: Color {
        if self.percentage < 50 { return AppTheme.accentGreen }
        if self.percentage < 80 { return AppTheme.accentOrange }
        return AppTheme.accentRed
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
                    .fill(AppTheme.screenBackground)
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
                    .fill(self.color)
                    .frame(width: geo.size.width * min(self.percentage / 100, 1.0), height: 4)
            }
        }
        .frame(width: 40, height: 4)
    }
}
