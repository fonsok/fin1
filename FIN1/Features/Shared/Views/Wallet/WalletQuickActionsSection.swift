import SwiftUI

/// Quick actions (Deposit / Withdrawal) for the wallet screen.
struct WalletQuickActionsSection: View {
    var onDeposit: () -> Void
    var onWithdrawal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("Schnellaktionen")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Button(action: onDeposit) {
                    VStack(spacing: ResponsiveDesign.spacing(2)) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: ResponsiveDesign.iconSize()))
                            .foregroundColor(.white)
                        Text("Einzahlen")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(ResponsiveDesign.spacing(4))
                    .background(AppTheme.accentGreen)
                    .cornerRadius(ResponsiveDesign.spacing(3))
                }

                Button(action: onWithdrawal) {
                    VStack(spacing: ResponsiveDesign.spacing(2)) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: ResponsiveDesign.iconSize()))
                            .foregroundColor(.white)
                        Text("Auszahlen")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(ResponsiveDesign.spacing(4))
                    .background(AppTheme.accentRed)
                    .cornerRadius(ResponsiveDesign.spacing(3))
                }
            }
        }
    }
}
