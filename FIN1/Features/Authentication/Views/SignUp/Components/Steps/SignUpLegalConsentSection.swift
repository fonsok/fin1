import SwiftUI

/// Legal Gate 1: explicit TOS + Privacy acceptance before persisting contact data.
struct SignUpLegalConsentSection: View {
    @Binding var acceptedTerms: Bool
    @Binding var acceptedPrivacyPolicy: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Rechtliche Einwilligungen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Toggle("I accept the Terms of Service", isOn: self.$acceptedTerms)
                .foregroundColor(AppTheme.fontColor)
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.accentLightBlue))
                .accessibilityIdentifier("SignUpAcceptTermsToggle")

            Toggle("I accept the Privacy Policy", isOn: self.$acceptedPrivacyPolicy)
                .foregroundColor(AppTheme.fontColor)
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.accentLightBlue))
                .accessibilityIdentifier("SignUpAcceptPrivacyToggle")
        }
    }
}

#Preview {
    SignUpLegalConsentSection(
        acceptedTerms: .constant(false),
        acceptedPrivacyPolicy: .constant(false)
    )
    .padding()
    .background(AppTheme.screenBackground)
}
