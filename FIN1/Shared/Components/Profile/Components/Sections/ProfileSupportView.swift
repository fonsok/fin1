import SwiftUI

struct ProfileSupportView: View {
    let onHelpCenter: () -> Void
    let onContactSupport: () -> Void
    let onTermsOfService: () -> Void
    let onPrivacyPolicy: () -> Void
    let onImprint: () -> Void

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            ProfileSectionTitle(title: "Support & Legal")
            ProfileSectionDivider()

            SettingsRow(
                title: "Help Center",
                subtitle: "FAQs and support articles",
                icon: "questionmark.circle.fill",
                color: AppTheme.accentLightBlue,
                action: self.onHelpCenter
            )

            ProfileSectionDivider()

            SettingsRow(
                title: "Contact Support",
                subtitle: "Get in touch with our team",
                icon: "message.fill",
                color: AppTheme.accentGreen,
                action: self.onContactSupport
            )

            ProfileSectionDivider()

            SettingsRow(
                title: "Terms of Service",
                subtitle: "Read our terms and conditions",
                icon: "doc.text.fill",
                color: AppTheme.accentOrange,
                action: self.onTermsOfService
            )

            ProfileSectionDivider()

            SettingsRow(
                title: "Privacy Policy",
                subtitle: "Learn about data protection",
                icon: "hand.raised.slash.fill",
                color: AppTheme.accentRed,
                action: self.onPrivacyPolicy
            )

            ProfileSectionDivider()

            SettingsRow(
                title: "Imprint",
                subtitle: "Legal disclosure (Impressum)",
                icon: "building.2.fill",
                color: AppTheme.accentLightBlue,
                action: self.onImprint
            )
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
