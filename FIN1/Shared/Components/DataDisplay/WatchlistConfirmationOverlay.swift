import SwiftUI

// MARK: - Watchlist Confirmation Overlay
struct WatchlistConfirmationOverlay: View {
    let title: String
    let systemImage: String
    let backgroundColor: Color

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: systemImage)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.screenBackground)

            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.screenBackground)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .padding(.vertical, ResponsiveDesign.spacing(10))
        .background(backgroundColor)
        .cornerRadius(ResponsiveDesign.spacing(12))
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityLabel(title)
    }
}

// MARK: - View Modifier
struct WatchlistConfirmationModifier: ViewModifier {
    let isShowing: Bool
    let title: String
    let systemImage: String
    let backgroundColor: Color

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isShowing {
                    WatchlistConfirmationOverlay(title: title, systemImage: systemImage, backgroundColor: backgroundColor)
                        .padding(.top, ResponsiveDesign.spacing(12))
                }
            }
    }
}

extension View {
    func watchlistConfirmation(isShowing: Bool, title: String, systemImage: String) -> some View {
        self.modifier(WatchlistConfirmationModifier(isShowing: isShowing, title: title, systemImage: systemImage, backgroundColor: AppTheme.accentLightBlue))
    }

    func watchlistError(isShowing: Bool, title: String) -> some View {
        self.modifier(WatchlistConfirmationModifier(isShowing: isShowing, title: title, systemImage: "exclamationmark.triangle.fill", backgroundColor: AppTheme.accentRed))
    }
}
