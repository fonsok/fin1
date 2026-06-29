import Foundation

extension SearchResult {

    /// Maps a depot position to the shared buy-order sheet input (search / watchlist / depot).
    init(depotHolding holding: DepotHolding) {
        self.init(
            valuationDate: holding.valuationDate,
            wkn: holding.wkn,
            strike: Self.formatPrice(holding.strike),
            askPrice: Self.formatPrice(holding.currentPrice),
            direction: holding.direction,
            category: holding.direction,
            underlyingType: nil,
            isin: holding.wkn,
            underlyingAsset: holding.underlyingAsset,
            denomination: holding.denomination,
            subscriptionRatio: holding.subscriptionRatio ?? 1.0
        )
    }

    private static func formatPrice(_ value: Double) -> String {
        value.formatted(.number.decimalSeparator(strategy: .automatic).precision(.fractionLength(0 ... 4)))
    }
}
