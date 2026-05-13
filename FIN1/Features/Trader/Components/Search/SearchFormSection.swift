import SwiftUI

struct SearchFormSection: View {
    @Binding var category: String
    @Binding var underlyingAsset: String
    @Binding var direction: SecuritiesSearchView.Direction
    @Binding var activeSheet: SecuritiesSearchView.ActiveSheet?

    let onBasiswertTap: () -> Void
    let onCategoryTap: () -> Void
    let savedFiltersContent: (() -> AnyView)?

    init(
        category: Binding<String>,
        underlyingAsset: Binding<String>,
        direction: Binding<SecuritiesSearchView.Direction>,
        activeSheet: Binding<SecuritiesSearchView.ActiveSheet?>,
        onBasiswertTap: @escaping () -> Void,
        onCategoryTap: @escaping () -> Void,
        savedFiltersContent: (() -> AnyView)? = nil
    ) {
        self._category = category
        self._underlyingAsset = underlyingAsset
        self._direction = direction
        self._activeSheet = activeSheet
        self.onBasiswertTap = onBasiswertTap
        self.onCategoryTap = onCategoryTap
        self.savedFiltersContent = savedFiltersContent
    }

    var body: some View {
        VStack(alignment: .center, spacing: ResponsiveDesign.spacing(20)) {
            Text("Derivate-Suche:")
                .font(ResponsiveDesign.titleFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.9))
                .padding(.top, ResponsiveDesign.spacing(16))

            // Saved Filters Section (if provided)
            if let savedFiltersContent = savedFiltersContent {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding(.vertical, ResponsiveDesign.spacing(8))

                savedFiltersContent()

                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding(.vertical, ResponsiveDesign.spacing(8))
            }

            // Kategorie Selection
            HStack {
                Text("Kategorie")
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .frame(width: 100, alignment: .leading)
                    .lineLimit(1)

                SearchField(
                    label: "Kategorie",
                    value: self.$category,
                    onTap: self.onCategoryTap
                )

                Spacer()
            }

            // Basiswert Selection
            HStack {
                Text("Basiswert")
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .frame(width: 100, alignment: .leading)
                    .lineLimit(1)

                SearchField(
                    label: "Basiswert",
                    value: self.$underlyingAsset,
                    subtitle: self.getBasiswertSubtitle(),
                    onTap: self.onBasiswertTap
                )

                Spacer()
            }

            // Market data row
            HStack {
                Spacer().frame(width: 100) // Align with underlyingAsset field
                MarketDataRow(underlyingAsset: self.underlyingAsset)
                Spacer()
            }

            // Richtung Selection
            HStack {
                Text("Richtung")
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .frame(width: 100, alignment: .leading)
                    .lineLimit(1)

                DirectionSegmentedControl(selection: self.$direction)

                Spacer()
            }
        }
    }

    private func getBasiswertSubtitle() -> String {
        // Use the WKN-based mapping from SearchResult to get the correct WKN
        let wkn = self.getWKNForBasiswert(self.underlyingAsset)
        let assetType = self.getAssetTypeForBasiswert(self.underlyingAsset)

        return "\(assetType) - \(wkn)"
    }

    private func getWKNForBasiswert(_ underlyingAsset: String) -> String {
        // Map underlyingAsset to WKN using the same logic as SearchResult
        switch underlyingAsset {
        // Stock WKNs
        case "Apple": return "865985"
        case "BMW": return "519000"
        case "Tesla": return "A1CX3T"
        case "Microsoft": return "870747"
        case "Google": return "A0B7X2"

        // Index WKNs
        case "DAX": return "846900"
        case "MDAX": return "846900"
        case "Dow Jones": return "846900"
        case "S&P 500": return "846900"
        case "NASDAQ 100": return "846900"
        case "Euro Stoxx 50": return "846900"
        case "FTSE 100": return "846900"
        case "CAC 40": return "846900"
        case "SMI": return "846900"

        // Commodity WKNs
        case "Gold": return "965515"
        case "Silber": return "965310"

        // Currency WKNs
        case "USD/JPY": return "965991"
        case "EUR/USD": return "965275"
        case "GBP/USD": return "965123"

        default: return "N/A"
        }
    }

    private func getAssetTypeForBasiswert(_ underlyingAsset: String) -> String {
        // Map underlyingAsset to asset type
        let indices = ["DAX", "MDAX", "Dow Jones", "S&P 500", "NASDAQ 100", "Euro Stoxx 50", "FTSE 100", "CAC 40", "SMI"]
        let aktien = ["Apple", "BMW", "Tesla", "Microsoft", "Google"]
        let metalle = ["Gold", "Silber"]
        let währungen = ["USD/JPY", "EUR/USD", "GBP/USD"]

        if indices.contains(underlyingAsset) {
            return "Index"
        } else if aktien.contains(underlyingAsset) {
            return "Aktie"
        } else if metalle.contains(underlyingAsset) {
            return "Rohstoff"
        } else if währungen.contains(underlyingAsset) {
            return "Devisen"
        } else {
            return "Index" // Default fallback
        }
    }
}

#Preview {
    SearchFormSection(
        category: .constant("Optionsschein"),
        underlyingAsset: .constant("DAX"),
        direction: .constant(.call),
        activeSheet: .constant(nil),
        onBasiswertTap: {},
        onCategoryTap: {}
    )
    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
    .padding(.top, ResponsiveDesign.spacing(8))
    .background(AppTheme.screenBackground)
}
