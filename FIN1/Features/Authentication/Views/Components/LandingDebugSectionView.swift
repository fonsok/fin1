import SwiftUI

/// Debug section for landing view (only visible in DEBUG builds)
struct LandingDebugSectionView: View {
    @ObservedObject var viewModel: LandingViewModel

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            // Debug toggle button
            Button(action: { viewModel.showDebugButtons.toggle() }, label: {
                if viewModel.designStyle == .typewriter {
                    Text("- Debug")
                        .font(ResponsiveDesign.monospacedFont(size: 14, weight: .regular))
                        .foregroundColor(Color("InputText"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack {
                        Image(systemName: viewModel.showDebugButtons ? "chevron.up" : "chevron.down")
                            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.75))
                        Text("Debug")
                            .font(ResponsiveDesign.captionFont())
                        Spacer()
                    }
                    .foregroundColor(AppTheme.accentLightBlue.opacity(0.7))
                    .padding(.horizontal, ResponsiveDesign.spacing(4))
                    .padding(.vertical, ResponsiveDesign.spacing(2))
                    .background(AppTheme.accentLightBlue.opacity(0.1))
                    .cornerRadius(ResponsiveDesign.spacing(8))
                }
            })
            .accessibilityIdentifier("DebugToggleButton")

            if viewModel.showDebugButtons {
                LandingDebugButtonsView(viewModel: viewModel)
            }
        }
    }
}

