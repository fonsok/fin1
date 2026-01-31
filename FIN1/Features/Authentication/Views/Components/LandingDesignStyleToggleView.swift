import SwiftUI

/// Design style toggle component shown at bottom of landing view
struct LandingDesignStyleToggleView: View {
    @Binding var designStyle: LandingViewModel.DesignStyle

    var body: some View {
        #if DEBUG
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Design Style:")
                    .font(designStyle == .typewriter
                          ? ResponsiveDesign.monospacedFont(size: 14, weight: .regular)
                          : ResponsiveDesign.captionFont())
                    .foregroundColor(designStyle == .typewriter ? Color("InputText") : AppTheme.tertiaryText)

                Spacer()

                Picker("", selection: $designStyle) {
                    ForEach(LandingViewModel.DesignStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
        .padding(.bottom, ResponsiveDesign.spacing(6))
        #endif
    }
}

