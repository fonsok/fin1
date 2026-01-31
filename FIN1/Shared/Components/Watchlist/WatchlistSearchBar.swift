import SwiftUI

// MARK: - Watchlist Search Bar
struct WatchlistSearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
            
            TextField("Search watchlist...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(AppTheme.fontColor)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                }
            }
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.inputFieldBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
