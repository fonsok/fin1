import SwiftUI

struct ProfileSupportView: View {
    let onHelpCenter: () -> Void
    let onContactSupport: () -> Void
    let onTermsOfService: () -> Void
    let onPrivacyPolicy: () -> Void
    let onImprint: () -> Void

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Text("Support & Legal")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
            }

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                SettingsRow(
                    title: "Help Center",
                    subtitle: "FAQs and support articles",
                    icon: "questionmark.circle.fill",
                    color: AppTheme.accentLightBlue,
                    action: onHelpCenter
                )

                SettingsRow(
                    title: "Contact Support",
                    subtitle: "Get in touch with our team",
                    icon: "message.fill",
                    color: AppTheme.accentGreen,
                    action: onContactSupport
                )

                SettingsRow(
                    title: "Terms of Service",
                    subtitle: "Read our terms and conditions",
                    icon: "doc.text.fill",
                    color: AppTheme.accentOrange,
                    action: onTermsOfService
                )

                SettingsRow(
                    title: "Privacy Policy",
                    subtitle: "Learn about data protection",
                    icon: "hand.raised.slash.fill",
                    color: AppTheme.accentRed,
                    action: onPrivacyPolicy
                )

                SettingsRow(
                    title: "Imprint",
                    subtitle: "Legal disclosure (Impressum)",
                    icon: "building.2.fill",
                    color: AppTheme.accentLightBlue,
                    action: onImprint
                )
            }
        }
    }
}

#Preview {
    ProfileSupportView(
        onHelpCenter: {},
        onContactSupport: {},
        onTermsOfService: {},
        onPrivacyPolicy: {},
        onImprint: {}
    )
    .padding()
    .background(AppTheme.screenBackground)
}
