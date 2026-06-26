import SwiftUI

/// Shown when the user is signed in but has not finished onboarding and the sign-up sheet is closed.
struct OnboardingPausedView: View {
    let onContinue: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            Image(systemName: "person.crop.circle.badge.clock")
                .font(.system(size: ResponsiveDesign.spacing(56)))
                .foregroundColor(AppTheme.accentLightBlue)

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                Text("Registrierung fortsetzen")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)

                Text(
                    "Ihr Konto wurde angelegt, die Registrierung ist aber noch nicht abgeschlossen. "
                        + "Sie können an der letzten Stelle weitermachen oder sich abmelden."
                )
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.center)
            }

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                Button(action: self.onContinue) {
                    Text("Registrierung fortsetzen")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.screenBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: ResponsiveDesign.spacing(50))
                        .background(AppTheme.accentLightBlue)
                        .cornerRadius(ResponsiveDesign.spacing(12))
                }
                .accessibilityIdentifier("OnboardingPausedContinueButton")

                Button(action: self.onSignOut) {
                    Text("Abmelden")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: ResponsiveDesign.spacing(50))
                        .overlay(
                            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                                .stroke(AppTheme.accentLightBlue, lineWidth: 2)
                        )
                }
                .accessibilityIdentifier("OnboardingPausedSignOutButton")
            }
            .padding(.top, ResponsiveDesign.spacing(8))
        }
        .padding(.horizontal, ResponsiveDesign.mainHorizontalPadding())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.screenBackground)
    }
}

#Preview {
    OnboardingPausedView(onContinue: {}, onSignOut: {})
}
