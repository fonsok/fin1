import SwiftUI

/// Search bar for canned response picker.
struct CannedResponsePickerSearchBar: View {
    @Binding var searchQuery: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.fontColor.opacity(0.5))

            TextField("Suchen oder /Kürzel eingeben...", text: $searchQuery)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
    }
}
