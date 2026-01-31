import SwiftUI

// MARK: - Watchlist Filter Tabs
struct WatchlistFilterTabs: View {
    @Binding var selectedFilter: WatchlistFilter
    
    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            ForEach(WatchlistFilter.allCases, id: \.self) { filter in
                Button(action: {
                    selectedFilter = filter
                }) {
                    Text(filter.displayName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(selectedFilter == filter ? AppTheme.screenBackground : AppTheme.fontColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? AppTheme.accentLightBlue : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(20))
                                .stroke(AppTheme.accentLightBlue, lineWidth: 1)
                        )
                        .cornerRadius(ResponsiveDesign.spacing(20))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
