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
                Button(action: self.onDeposit) {
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
                    .background(self.actionsEnabled ? AppTheme.accentGreen : AppTheme.secondaryText)
                    .cornerRadius(ResponsiveDesign.spacing(3))
                }
                .disabled(!self.actionsEnabled)

                Button(action: self.onWithdrawal) {
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
                    .background(self.actionsEnabled ? AppTheme.accentRed : AppTheme.secondaryText)
                    .cornerRadius(ResponsiveDesign.spacing(3))
                }
                .disabled(!self.actionsEnabled)
            }
        }
    }
}
