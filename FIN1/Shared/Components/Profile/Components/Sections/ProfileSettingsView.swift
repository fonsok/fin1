import SwiftUI

struct ProfileSettingsView: View {
    let onPrivacy: () -> Void
    let onSecurity: () -> Void
    let onAppearance: () -> Void

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            ProfileSectionTitle(title: "Settings & Preferences")
            ProfileSectionDivider()

            SettingsRow(
                title: "Privacy",
                subtitle: "Control your data and privacy",
                icon: "hand.raised.fill",
                color: AppTheme.accentGreen,
                action: self.onPrivacy
            )

            ProfileSectionDivider()

            SettingsRow(
                title: "Security",
                subtitle: "Password, 2FA, and security",
                icon: "lock.shield.fill",
                color: AppTheme.accentRed,
                action: self.onSecurity
            )

            ProfileSectionDivider()

            SettingsRow(
                title: "Appearance",
                subtitle: "Theme and display settings",
                icon: "paintbrush.fill",
                color: AppTheme.accentLightBlue,
                action: self.onAppearance
            )
        }
    }
}

struct SettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: self.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(self.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(self.title)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Text(self.subtitle)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
            .padding(ResponsiveDesign.spacing(12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileSettingsView(
        onPrivacy: {},
        onSecurity: {},
        onAppearance: {}
    )
    .padding()
    .background(AppTheme.screenBackground)
}
