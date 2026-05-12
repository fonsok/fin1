import SwiftUI

/// Quick actions (Deposit / Withdrawal) for the wallet screen.
struct WalletQuickActionsSection: View {
    var actionsEnabled: Bool
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
                            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                            .foregroundColor(.white)
                        Text("Einzahlen")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(ResponsiveDesign.spacing(4))
                    .background(actionsEnabled ? AppTheme.accentGreen : AppTheme.secondaryText)
                    .cornerRadius(ResponsiveDesign.spacing(3))
                }
                .disabled(!actionsEnabled)

                Button(action: onWithdrawal) {
                    VStack(spacing: ResponsiveDesign.spacing(2)) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                            .foregroundColor(.white)
                        Text("Auszahlen")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(ResponsiveDesign.spacing(4))
                    .background(actionsEnabled ? AppTheme.accentRed : AppTheme.secondaryText)
                    .cornerRadius(ResponsiveDesign.spacing(3))
                }
                .disabled(!actionsEnabled)
            }
        }
    }
}
