import SwiftUI

// MARK: - Reusable step UI helpers for Company KYB wizard

func stepHeader(title: String, subtitle: String) -> some View {
    VStack(spacing: ResponsiveDesign.spacing(4)) {
        Text(title)
            .font(ResponsiveDesign.headlineFont())
            .fontWeight(.bold)
            .foregroundColor(AppTheme.fontColor)
            .multilineTextAlignment(.center)

        Text(subtitle)
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.8))
            .multilineTextAlignment(.center)
    }
}

func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
    Toggle(isOn: isOn) {
        Text(title)
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(AppTheme.fontColor)
            .fixedSize(horizontal: false, vertical: true)
    }
    .tint(AppTheme.accentLightBlue)
    .padding(ResponsiveDesign.spacing(12))
    .background(AppTheme.sectionBackground)
    .cornerRadius(ResponsiveDesign.isCompactDevice() ? 12 : 16)
}
