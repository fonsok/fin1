import SwiftUI

// MARK: - Watchlist Button
struct WatchlistButton: View {
    let isInWatchlist: Bool
    let onToggle: ((Bool) -> Void)?
    let isBusy: Bool

    var body: some View {
        Button(action: {
            print("🔘 WatchlistButton tapped: isInWatchlist=\(self.isInWatchlist), onToggle is \(onToggle != nil ? "not nil" : "nil")")
            if let onToggle = onToggle {
                print("🔘 Calling onToggle with \(!self.isInWatchlist)")
                onToggle(!self.isInWatchlist)
            } else {
                print("❌ onToggle is nil - button won't work!")
            }
        }) {
            Image(systemName: self.isInWatchlist ? "star.fill" : "star")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(self.isInWatchlist ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.6))
                .opacity(self.isBusy ? 0.4 : 1.0)
        }
        .disabled(self.isBusy)
        .frame(width: ResponsiveDesign.iconSize(), alignment: .center)
        .padding(ResponsiveDesign.spacing(0)) // Remove any internal padding
    }
}
