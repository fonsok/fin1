import SwiftUI

// MARK: - Info Overlay
/// Simple info overlay that displays a message and auto-dismisses
struct InfoOverlay: View {
    let message: String
    let isVisible: Bool

    var body: some View {
        if self.isVisible {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                // Info content
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    // Info icon
                    Image(systemName: "info.circle.fill")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2.5))
                        .foregroundColor(AppTheme.accentLightBlue)

                    // Message
                    Text(self.message)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ResponsiveDesign.spacing(24))
                }
                .padding(ResponsiveDesign.spacing(24))
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(16))
                .shadow(radius: 8)
                .padding(.horizontal, ResponsiveDesign.spacing(32))
            }
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.3), value: self.isVisible)
        }
    }
}










