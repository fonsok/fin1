import SwiftUI

struct FeatureRow: View {
    let icon: String
    let text: String
    let style: LandingViewModel.DesignStyle
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            if style == .typewriter {
                Text("-")
                    .font(ResponsiveDesign.monospacedFont(size: 16, weight: .regular))
                    .foregroundColor(Color("InputText"))
            } else {
                Image(systemName: icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentGreen)
                    .frame(width: 24)
            }

            Text(text)
                .font(style == .typewriter
                      ? ResponsiveDesign.monospacedFont(size: 16, weight: .regular)
                      : ResponsiveDesign.bodyFont())
                .foregroundColor(style == .typewriter ? Color("InputText") : AppTheme.primaryText)

            Spacer()
        }
    }
}
