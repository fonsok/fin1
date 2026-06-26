import SwiftUI

// Import UI components
// Note: These components are now in the UI subfolder

struct TermsStep: View {
    @Binding var acceptedTerms: Bool
    @Binding var acceptedPrivacyPolicy: Bool
    @Binding var acceptedMarketingConsent: Bool

    var body: some View {
        SignUpStepList {
            Text("Terms & Conditions")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .signUpListSection(stripeIndex: 0)

            SignUpLegalConsentSection(
                acceptedTerms: self.$acceptedTerms,
                acceptedPrivacyPolicy: self.$acceptedPrivacyPolicy
            )
            .signUpListSection(stripeIndex: 1)

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Toggle(
                    "I agree that information about products and promotional offers may be sent to me.",
                    isOn: self.$acceptedMarketingConsent
                )
                .foregroundColor(AppTheme.fontColor)
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.accentLightBlue))
            }
            .signUpListSection(stripeIndex: 2)

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Was Sie akzeptieren:")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    InfoBullet(text: "Nutzungsbedingungen für unsere App")
                    InfoBullet(text: "Datenschutzrichtlinien und -verarbeitung")
                    InfoBullet(text: "Regulatorische Compliance-Anforderungen")
                    InfoBullet(text: "Risikohinweise für Finanzprodukte")
                }
            }
            .signUpListSection(stripeIndex: 3)

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.accentOrange)
                        .font(ResponsiveDesign.headlineFont())

                    Text("Wichtiger Hinweis")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    Spacer()
                }

                Text(
                    "Bitte lesen Sie die vollständigen Bedingungen und Datenschutzrichtlinien, bevor Sie fortfahren. Diese enthalten wichtige Informationen zu Ihren Rechten und Pflichten."
                )
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.leading)
            }
            .signUpListSection(stripeIndex: 4, bandTint: AppTheme.accentOrange)
        }
    }
}

#Preview {
    TermsStep(
        acceptedTerms: .constant(false),
        acceptedPrivacyPolicy: .constant(false),
        acceptedMarketingConsent: .constant(false)
    )
    .background(AppTheme.screenBackground)
}
