import SwiftUI

// MARK: - Trader Tab Navigation View
/// Tab navigation for trader details

struct TraderTabNavigationView: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(0)) {
            ForEach(0..<4) { index in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: ResponsiveDesign.spacing(4)) {
                        Text(tabTitle(for: index))
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(selectedTab == index ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.6))

                        Rectangle()
                            .fill(selectedTab == index ? AppTheme.accentLightBlue : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .responsivePadding()
        .background(AppTheme.systemSecondaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Performance"
        case 1: return "Reviews"
        case 2: return "Risk Analysis"
        case 3: return "History"
        default: return ""
        }
    }
}
