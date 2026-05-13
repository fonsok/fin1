import SwiftUI

/// Balance card for the wallet screen (title, amount, demo badge).
struct WalletBalanceCard: View {
    let formattedBalance: String

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            Text("Aktuelles Guthaben")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)

            Text(self.formattedBalance)
                .font(ResponsiveDesign.largeTitleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            HStack(spacing: ResponsiveDesign.spacing(2)) {
                Image(systemName: "info.circle.fill")
                    .font(ResponsiveDesign.captionFont())
                Text("Demo-Modus")
                    .font(ResponsiveDesign.captionFont())
            }
            .foregroundColor(AppTheme.accentOrange)
            .padding(.horizontal, ResponsiveDesign.spacing(3))
            .padding(.vertical, ResponsiveDesign.spacing(2))
            .background(AppTheme.accentOrange.opacity(0.1))
            .cornerRadius(ResponsiveDesign.spacing(3))
        }
        .frame(maxWidth: .infinity)
        .padding(ResponsiveDesign.spacing(6))
        .background(AppTheme.cardBackground)
        .cornerRadius(ResponsiveDesign.spacing(3))
    }
}
