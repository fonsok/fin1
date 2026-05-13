import SwiftUI

// MARK: - Security Toggle Row

struct SecurityToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool

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
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.accentLightBlue))
        }
    }
}

// MARK: - Two-Factor Method Row

struct TwoFactorMethodRow: View {
    let method: TwoFactorMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack {
                Image(systemName: self.method.iconName)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(self.isSelected ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.5))
                    .frame(width: 24)

                Text(self.method.rawValue)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                if self.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
            .padding(ResponsiveDesign.spacing(12))
            .background(self.isSelected ? AppTheme.accentLightBlue.opacity(0.1) : AppTheme.systemTertiaryBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }
}

// MARK: - Security Event Row

struct SecurityEventRow: View {
    let event: SecurityEvent

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: self.event.type.iconName)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(self.eventColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                Text(self.event.description)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                HStack {
                    Text(self.event.timestamp, style: .relative)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))

                    if let location = event.location {
                        Text("•")
                            .foregroundColor(AppTheme.fontColor.opacity(0.4))
                        Text(location)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    }
                }
            }

            Spacer()
        }
        .padding(ResponsiveDesign.spacing(8))
        .background(AppTheme.systemTertiaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(6))
    }

    private var eventColor: Color {
        switch self.event.type.color {
        case "green": return AppTheme.accentGreen
        case "orange": return AppTheme.accentOrange
        case "blue": return AppTheme.accentLightBlue
        case "red": return AppTheme.accentRed
        default: return AppTheme.fontColor
        }
    }
}





