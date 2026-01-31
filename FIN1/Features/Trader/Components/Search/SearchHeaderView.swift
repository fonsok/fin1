import SwiftUI

struct SearchHeaderView: View {
    @Binding var searchText: String
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        HStack {
            TextField("WKN/ISIN Derivat", text: $searchText)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.inputFieldText)
                .padding(ResponsiveDesign.spacing(8))
                .background(AppTheme.inputFieldBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
                .accessibilityIdentifier("SecuritiesSearchField")
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.fontColor)
        }
        .padding(.horizontal)
    }
}

#Preview {
    SearchHeaderView(searchText: .constant(""))
        .padding()
        .background(AppTheme.screenBackground)
}
