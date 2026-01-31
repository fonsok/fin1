import SwiftUI

// MARK: - Trader Watchlist Empty State
struct TraderWatchlistEmptyState: View {
    @Environment(\.appServices) private var services
    @State private var showSecuritiesSearch = false

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            Image(systemName: "star")
                .font(.system(size: ResponsiveDesign.iconSize() * 3.2))
                .foregroundColor(AppTheme.accentLightBlue.opacity(0.6))

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                Text("No Watched Securities")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Text("Start watching securities to track their prices and get trading alerts.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ResponsiveDesign.spacing(32))
            }

            Button(action: {
                showSecuritiesSearch = true
            }, label: {
                Text("Discover Securities")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .padding(.horizontal, ResponsiveDesign.spacing(24))
                    .padding(.vertical, ResponsiveDesign.spacing(12))
                    .background(AppTheme.accentLightBlue)
                    .cornerRadius(ResponsiveDesign.spacing(8))
            })
        }
        .padding(.top, ResponsiveDesign.spacing(60))
        .sheet(isPresented: $showSecuritiesSearch) {
            SecuritiesSearchView(services: services)
        }
    }
}
