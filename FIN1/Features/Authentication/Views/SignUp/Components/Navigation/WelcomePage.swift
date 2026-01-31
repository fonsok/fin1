import SwiftUI

struct WelcomePage: View {
    @Environment(\.dismiss) private var dismiss
    let coordinator: SignUpCoordinator

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(32)) {
            Spacer()

            // Success icon
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppTheme.accentGreen)

                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    Text("Herzlich willkommen und viel Erfolg!")
                        .font(ResponsiveDesign.titleFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)
                        .multilineTextAlignment(.center)

                    Text("Ihre Registrierung wurde erfolgreich abgeschlossen. Sie können sich jetzt mit Ihren Zugangsdaten anmelden.")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: ResponsiveDesign.spacing(16)) {

                    Text("Überweisen Sie von Ihrem Privatkonto auf Ihr \(AppBrand.appName)-Cashkonto die Ihre gewünschte Investitionssumme und Sie können sofort loslegen. Ihr dabei eingesetztes Privatkonto führen wir als Ihr persönliches Referenzkonto bei uns.")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()

            // Action button
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Button("Zur Startseite") {
                    // Request complete dismissal to return to LandingView
                    coordinator.requestDismissal()
                }
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity)
                .responsivePadding()
                .background(AppTheme.buttonColor)
                .cornerRadius(ResponsiveDesign.spacing(12))
                .padding(.horizontal)
            }
        }
        .responsivePadding()
        .background(AppTheme.screenBackground)
        // Note: Dismissal returns to the original LandingView
    }
}

#Preview {
    WelcomePage(coordinator: SignUpCoordinator())
}
