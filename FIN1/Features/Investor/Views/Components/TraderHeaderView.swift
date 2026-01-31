import SwiftUI
import Foundation

// MARK: - Trader Header View
/// Displays trader identification with person icon, username, and date

struct TraderHeaderView: View {
    let trader: MockTrader
    @Environment(\.themeManager) private var themeManager

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        let dateString = formatter.string(from: Date())
        return "today, \(dateString)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: ResponsiveDesign.spacing(12)) {
            // Person icon in square frame
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .fill(AppTheme.accentLightBlue.opacity(0.2))
                .frame(width: ResponsiveDesign.iconSize() * 2, height: ResponsiveDesign.iconSize() * 2)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: ResponsiveDesign.iconSize() * 1.2))
                        .foregroundColor(AppTheme.accentLightBlue)
                )

            // Username and Date
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                // Username with reduced font size
                Text(trader.username)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                // Date formatted as "today, DD.MM.YYYY"
                Text(formattedDate)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.systemTertiaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }
}
