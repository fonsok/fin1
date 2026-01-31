import SwiftUI

struct ProfileSettingsView: View {
    let onPrivacy: () -> Void
    let onSecurity: () -> Void
    let onAppearance: () -> Void

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Text("Settings & Preferences")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
            }

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                SettingsRow(
                    title: "Privacy",
                    subtitle: "Control your data and privacy",
                    icon: "hand.raised.fill",
                    color: AppTheme.accentGreen,
                    action: onPrivacy
                )

                SettingsRow(
                    title: "Security",
                    subtitle: "Password, 2FA, and security",
                    icon: "lock.shield.fill",
                    color: AppTheme.accentRed,
                    action: onSecurity
                )

                SettingsRow(
                    title: "Appearance",
                    subtitle: "Theme and display settings",
                    icon: "paintbrush.fill",
                    color: AppTheme.accentLightBlue,
                    action: onAppearance
                )
            }
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
        Button(action: action, label: {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Text(subtitle)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
            .padding(ResponsiveDesign.spacing(12))
            .background(AppTheme.systemTertiaryBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        })
        .buttonStyle(PlainButtonStyle())
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
