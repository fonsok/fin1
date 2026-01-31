import SwiftUI

/// Generic Quick Action Card component for dashboard quick actions
/// Used to display action buttons in a grid layout
struct DashboardQuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        Button(action: action, label: {
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: icon)
                    .font(.system(size: ResponsiveDesign.iconSize()))
                    .foregroundColor(color)

                Text(title)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: ResponsiveDesign.spacing(80))
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))
        })
        .accessibilityLabel(title)
        .accessibilityHint("Tap to \(title.lowercased())")
    }
}

#Preview {
    HStack(spacing: ResponsiveDesign.spacing(16)) {
        DashboardQuickActionCard(
            title: "Get Started",
            icon: "play.circle.fill",
            color: AppTheme.accentGreen
        ) {
            print("Get Started tapped")
        }

        DashboardQuickActionCard(
            title: "Learn More",
            icon: "book.fill",
            color: AppTheme.accentLightBlue
        ) {
            print("Learn More tapped")
        }
    }
    .padding()
    .background(AppTheme.screenBackground)
}

