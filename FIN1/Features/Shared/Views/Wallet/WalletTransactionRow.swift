import SwiftUI

/// Single transaction row for wallet and history lists.
struct WalletTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(4)) {
            Image(systemName: transaction.type.icon)
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                .foregroundColor(colorForType(transaction.type))
                .frame(width: ResponsiveDesign.spacing(8), height: ResponsiveDesign.spacing(8))
                .background(colorForType(transaction.type).opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(3))

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                Text(transaction.type.displayName)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                if let description = transaction.description {
                    Text(description)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.secondaryText)
                }

                Text(transaction.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()

            Text(transaction.formattedSignedAmount)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(transaction.isPositive ? AppTheme.accentGreen : AppTheme.accentRed)
        }
        .padding(ResponsiveDesign.spacing(4))
        .background(AppTheme.cardBackground)
        .cornerRadius(ResponsiveDesign.spacing(3))
    }

    private func colorForType(_ type: Transaction.TransactionType) -> Color {
        switch type.color {
        case "green": return AppTheme.accentGreen
        case "red": return AppTheme.accentRed
        case "blue": return AppTheme.accentLightBlue
        case "orange": return AppTheme.accentOrange
        default: return AppTheme.secondaryText
        }
    }
}
