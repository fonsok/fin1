import SwiftUI

struct FeatureRow: View {
    let icon: String
    let text: String
    let style: LandingViewModel.DesignStyle
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            if self.style == .typewriter {
                Text("-")
                    .font(ResponsiveDesign.monospacedFont(size: 16, weight: .regular))
                    .foregroundColor(Color("InputText"))
            } else {
                Image(systemName: self.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentGreen)
                    .frame(width: 24)
            }

            Text(self.text)
                .font(self.style == .typewriter
                    ? ResponsiveDesign.monospacedFont(size: 16, weight: .regular)
                    : ResponsiveDesign.bodyFont())
                .foregroundColor(self.style == .typewriter ? Color("InputText") : AppTheme.primaryText)

            Spacer()
        }
    }
}
