import SwiftUI

// MARK: - Settings Toggle Row
/// Reusable toggle row component for settings screens
/// Follows DRY principle by consolidating PrivacyToggleRow, SecurityToggleRow, NotificationToggleRow
struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool
    var tintColor: Color = AppTheme.accentLightBlue

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text(self.title)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text(self.subtitle)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            Spacer()

            Toggle("", isOn: self.$isEnabled)
                .toggleStyle(SwitchToggleStyle(tint: self.tintColor))
        }
    }
}

// MARK: - Settings Text Field Style
/// Reusable text field style for settings screens
struct SettingsTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        let padding = MainActor.assumeIsolated { ResponsiveDesign.spacing(12) }
        let cornerRadius = MainActor.assumeIsolated { ResponsiveDesign.spacing(8) }
        configuration
            .padding(padding)
            .background(AppTheme.systemTertiaryBackground)
            .cornerRadius(cornerRadius)
            .foregroundColor(AppTheme.fontColor)
    }
}

// MARK: - Settings Secure Field Style
/// Reusable secure field style for settings screens
struct SettingsSecureFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        let padding = MainActor.assumeIsolated { ResponsiveDesign.spacing(16) }
        let cornerRadius = MainActor.assumeIsolated { ResponsiveDesign.spacing(12) }
        configuration
            .padding(padding)
            .background(AppTheme.systemTertiaryBackground)
            .cornerRadius(cornerRadius)
            .foregroundColor(AppTheme.fontColor)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(16)) {
        SettingsToggleRow(
            title: "Enable Feature",
            subtitle: "Description of this feature",
            isEnabled: .constant(true)
        )

        SettingsToggleRow(
            title: "Another Feature",
            subtitle: "Another description",
            isEnabled: .constant(false),
            tintColor: AppTheme.accentGreen
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
}





