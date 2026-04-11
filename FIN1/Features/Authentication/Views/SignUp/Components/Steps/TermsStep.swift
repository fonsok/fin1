import SwiftUI

// Import UI components
// Note: These components are now in the UI subfolder

struct TermsStep: View {
    @Binding var acceptedTerms: Bool
    @Binding var acceptedPrivacyPolicy: Bool
    @Binding var acceptedMarketingConsent: Bool

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            Text("Terms & Conditions")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Toggle("I accept the Terms of Service", isOn: $acceptedTerms)
                    .foregroundColor(AppTheme.fontColor)
                    .toggleStyle(SwitchToggleStyle(tint: AppTheme.accentLightBlue))

                Toggle("I accept the Privacy Policy", isOn: $acceptedPrivacyPolicy)
                    .foregroundColor(AppTheme.fontColor)
                    .toggleStyle(SwitchToggleStyle(tint: AppTheme.accentLightBlue))

                Toggle("I agree that information about products and promotional offers may be sent to me.", isOn: $acceptedMarketingConsent)
                    .foregroundColor(AppTheme.fontColor)
                    .toggleStyle(SwitchToggleStyle(tint: AppTheme.accentLightBlue))
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))

            // Terms Explanation
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Was Sie akzeptieren:")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    InfoBullet(text: "Nutzungsbedingungen für unsere App")
                    InfoBullet(text: "Datenschutzrichtlinien und -verarbeitung")
                    InfoBullet(text: "Regulatorische Compliance-Anforderungen")
                    InfoBullet(text: "Risikohinweise für Finanzprodukte")
                }
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))

            // Important Notice
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

                Text("Bitte lesen Sie die vollständigen Bedingungen und Datenschutzrichtlinien, bevor Sie fortfahren. Diese enthalten wichtige Informationen zu Ihren Rechten und Pflichten.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(AppTheme.accentOrange.opacity(0.1))
            .cornerRadius(ResponsiveDesign.spacing(12))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                    .stroke(AppTheme.accentOrange.opacity(0.3), lineWidth: 1)
            )
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
