import SwiftUI

struct DepotOverview: View {
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            // Total Depot Value
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                Text("Total Depot Value")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))

                Text("$67,450")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 1.8, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.fontColor)

                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "arrow.up.right")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentGreen)

                    Text("+$4,200 (+6.6%)")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentGreen)

                    Text("This Month")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                }
            }

            // Quick Stats
            HStack(spacing: ResponsiveDesign.spacing(20)) {
                DepotStatItem(
                    title: "Cash Balance",
                    value: "$15,000",
                    icon: "dollarsign.circle.fill",
                    color: AppTheme.accentGreen
                )

                DepotStatItem(
                    title: "Positions",
                    value: "8",
                    icon: "chart.bar.fill",
                    color: AppTheme.accentLightBlue
                )

                DepotStatItem(
                    title: "Total P&L",
                    value: "+$4,200",
                    icon: "chart.line.uptrend.xyaxis",
                    color: AppTheme.accentGreen
                )
            }
        }
        .padding(ResponsiveDesign.spacing(20))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .padding(.top, ResponsiveDesign.spacing(16))
    }
}

struct DepotStatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: icon)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(color)

            Text(value)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text(title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DepotOverview()
}
