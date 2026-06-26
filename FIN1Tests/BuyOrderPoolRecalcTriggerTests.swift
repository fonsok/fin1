@testable import FIN1
import XCTest

final class BuyOrderPoolRecalcTriggerTests: XCTestCase {

    func testSecurityInputsIgnoreUnrelatedSearchResultFields() {
        let base = Self.makeSearchResult(askPrice: "1,50")
        let withNewValuation = SearchResult(
            valuationDate: "2026-06-27",
            wkn: base.wkn,
            strike: base.strike,
            askPrice: base.askPrice,
            direction: base.direction,
            category: base.category,
            underlyingType: base.underlyingType,
            isin: base.isin,
            underlyingAsset: base.underlyingAsset,
            denomination: base.denomination,
            subscriptionRatio: base.subscriptionRatio,
            minimumOrderAmount: base.minimumOrderAmount
        )

        XCTAssertEqual(
            buyOrderPoolRecalcSecurityInputs(from: base),
            buyOrderPoolRecalcSecurityInputs(from: withNewValuation)
        )
    }

    func testSecurityInputsChangeWhenAskPriceChanges() {
        let first = Self.makeSearchResult(askPrice: "1,50")
        let second = Self.makeSearchResult(askPrice: "1,55")

        XCTAssertNotEqual(
            buyOrderPoolRecalcSecurityInputs(from: first),
            buyOrderPoolRecalcSecurityInputs(from: second)
        )
    }

    func testPoolSnapshotDetectsCapitalChange() {
        let empty = BuyOrderPoolInvestmentSnapshot(investmentCount: 0, totalCapital: 0)
        let funded = BuyOrderPoolInvestmentSnapshot(investmentCount: 2, totalCapital: 5_000)

        XCTAssertNotEqual(empty, funded)
    }

    private static func makeSearchResult(askPrice: String) -> SearchResult {
        SearchResult(
            valuationDate: "2026-06-26",
            wkn: "TEST123",
            strike: "100",
            askPrice: askPrice,
            direction: "Call",
            category: "Optionsschein",
            underlyingType: "Index",
            isin: "DE000TEST123",
            underlyingAsset: "DAX",
            denomination: 1,
            subscriptionRatio: 0.1,
            minimumOrderAmount: 1_000
        )
    }
}
