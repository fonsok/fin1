import SwiftUI

// MARK: - Trader Watchlist Success Message Overlay
struct TraderWatchlistSuccessMessageOverlay: View {
    let message: String
    let isVisible: Bool

    var body: some View {
        if isVisible {
            VStack {
                Spacer()

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.accentGreen)

                    Text(message)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                }
                .padding(.horizontal, ResponsiveDesign.spacing(20))
                .padding(.vertical, ResponsiveDesign.spacing(12))
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
                .shadow(radius: 4)

                Spacer()
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Auto-hide after 2 seconds
                }
            }
        }
    }
}
