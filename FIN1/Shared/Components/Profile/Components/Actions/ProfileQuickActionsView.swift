import SwiftUI

struct ProfileQuickActionsView: View {
    let onEditProfile: () -> Void
    let onSettings: () -> Void
    let onSecurity: () -> Void
    let onHelpSupport: () -> Void

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Text("Quick Actions")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: ResponsiveDesign.spacing(16)) {
                ProfileQuickActionCard(
                    title: "Edit Profile",
                    icon: "person.circle.fill",
                    color: AppTheme.accentLightBlue,
                    action: self.onEditProfile
                )

                ProfileQuickActionCard(
                    title: "Settings",
                    icon: "gearshape.fill",
                    color: AppTheme.accentOrange,
                    action: self.onSettings
                )

                ProfileQuickActionCard(
                    title: "Security",
                    icon: "lock.shield.fill",
                    color: AppTheme.accentGreen,
                    action: self.onSecurity
                )

                ProfileQuickActionCard(
                    title: "Help & Support",
                    icon: "questionmark.circle.fill",
                    color: AppTheme.accentRed,
                    action: self.onHelpSupport
                )
            }
        }
    }
}

struct ProfileQuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: self.action, label: {
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: self.icon)
                    .font(ResponsiveDesign.titleFont())
                    .foregroundColor(self.color)

                Text(self.title)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(AppTheme.systemTertiaryBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))
        })
    }
}

#Preview {
    ProfileQuickActionsView(
        onEditProfile: {},
        onSettings: {},
        onSecurity: {},
        onHelpSupport: {}
    )
    .padding()
    .background(AppTheme.screenBackground)
}
