import SwiftUI

/// Recent transactions list with "Alle anzeigen" and empty state.
struct WalletRecentTransactionsSection: View {
    let transactions: [Transaction]
    var onShowAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            HStack {
                Text("Letzte Transaktionen")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Button(action: onShowAll) {
                    Text("Alle anzeigen")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }

            if transactions.isEmpty {
                emptyTransactionsView
            } else {
                ForEach(Array(transactions.prefix(5))) { transaction in
                    WalletTransactionRow(transaction: transaction)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
    }

    private var emptyTransactionsView: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            Image(systemName: "tray")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.secondaryText.opacity(0.6))
            Text("Noch keine Transaktionen")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)
            Text("Ihre Transaktionen werden hier angezeigt")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(ResponsiveDesign.spacing(8))
        .background(AppTheme.cardBackground.opacity(0.5))
        .cornerRadius(ResponsiveDesign.spacing(3))
    }
}
