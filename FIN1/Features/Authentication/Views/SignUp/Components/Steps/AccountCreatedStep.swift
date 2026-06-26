import SwiftUI

struct AccountCreatedStep: View {
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(32)) {
            Image(systemName: "checkmark.circle.fill")
                .font(ResponsiveDesign.scaledSystemFont(size: 80))
                .foregroundColor(AppTheme.accentGreen)

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Ihr Konto wurde angelegt.")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("SignUpAccountCreatedTitle")

                Text(
                    "Die Registrierung wurde gestartet. Bitte schließen Sie die weiteren Schritte ab, "
                        + "bevor Sie die App vollständig nutzen können."
                )
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    AccountCreatedStep()
        .background(AppTheme.screenBackground)
}
