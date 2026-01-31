import SwiftUI

// MARK: - Contact Method Button

struct ContactMethodButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: icon)
                    .font(.system(size: ResponsiveDesign.iconSize() * 1.5))
                    .foregroundColor(color)

                Text(title)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
            }
            .frame(maxWidth: .infinity)
            .padding(ResponsiveDesign.spacing(16))
            .background(color.opacity(0.1))
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
    }
}

// MARK: - Contact Info Row

struct ContactInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: icon)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                Text(label)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))

                Text(value)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
            }

            Spacer()
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.systemTertiaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Support Category Color Helper

struct SupportCategoryHelper {
    static func color(for category: SupportCategory) -> Color {
        switch category.color {
        case "blue": return AppTheme.accentLightBlue
        case "orange": return AppTheme.accentOrange
        case "purple": return .purple
        case "green": return AppTheme.accentGreen
        case "cyan": return .cyan
        case "red": return AppTheme.accentRed
        case "yellow": return .yellow
        default: return AppTheme.fontColor
        }
    }

    static func priorityColor(for priority: SupportPriority) -> Color {
        switch priority.color {
        case "red": return AppTheme.accentRed
        case "orange": return AppTheme.accentOrange
        case "green": return AppTheme.accentGreen
        default: return AppTheme.fontColor
        }
    }
}





