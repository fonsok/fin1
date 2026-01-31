import SwiftUI

// MARK: - Investment Pool Info Row
/// A row component for displaying investment pool information

struct InvestmentPoolInfoRow: View {
    let pool: InvestmentPool
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            // Investment Icon
            Circle()
                .fill(Color(pool.status.color).opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "building.2.fill")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(Color(pool.status.color))
                )

            // Investment Info
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text("Investment #\(pool.poolNumber)")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Text(pool.currentBalance.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()

            // Status
            VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(4)) {
                Text(pool.status.displayName)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(Color(pool.status.color))

                Text("\(pool.numberOfInvestors) investors")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}
