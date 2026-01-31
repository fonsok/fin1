import SwiftUI

// MARK: - Watchlist Button
struct WatchlistButton: View {
    let isInWatchlist: Bool
    let onToggle: ((Bool) -> Void)?
    let isBusy: Bool

    var body: some View {
        Button(action: {
            print("🔘 WatchlistButton tapped: isInWatchlist=\(isInWatchlist), onToggle is \(onToggle != nil ? "not nil" : "nil")")
            if let onToggle = onToggle {
                print("🔘 Calling onToggle with \(!isInWatchlist)")
                onToggle(!isInWatchlist)
            } else {
                print("❌ onToggle is nil - button won't work!")
            }
        }) {
            Image(systemName: isInWatchlist ? "star.fill" : "star")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(isInWatchlist ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.6))
                .opacity(isBusy ? 0.4 : 1.0)
        }
        .disabled(isBusy)
        .frame(width: ResponsiveDesign.iconSize(), alignment: .center)
        .padding(ResponsiveDesign.spacing(0)) // Remove any internal padding
    }
}
