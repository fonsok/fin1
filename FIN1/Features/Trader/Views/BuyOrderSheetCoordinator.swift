import SwiftUI

/// Single presentation path for the trader buy-order sheet (`.sheet(item:)` + `BuyOrderViewWrapper`).
/// Prevents split `@State` / external ViewModel regressions — see `.cursor/rules/architecture.md`.
struct BuyOrderSheetCoordinator: ViewModifier {
    @Binding var selectedSecurity: SearchResult?
    let services: AppServices
    var onOrderPlaced: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .sheet(item: self.$selectedSecurity) { searchResult in
                BuyOrderViewWrapper(
                    searchResult: searchResult,
                    services: self.services,
                    onOrderPlaced: {
                        self.selectedSecurity = nil
                        self.onOrderPlaced?()
                    }
                )
            }
    }
}

extension View {

    /// Presents the buy-order sheet when `item` is non-nil; clears `item` after successful placement.
    func buyOrderSheet(
        item: Binding<SearchResult?>,
        services: AppServices,
        onOrderPlaced: (() -> Void)? = nil
    ) -> some View {
        self.modifier(
            BuyOrderSheetCoordinator(
                selectedSecurity: item,
                services: services,
                onOrderPlaced: onOrderPlaced
            )
        )
    }
}
