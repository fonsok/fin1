@testable import FIN1
import XCTest

final class BuyOrderPlacementSessionTests: XCTestCase {

    func testCanStartPlacement_fromEditingAndFailed_only() {
        var session = BuyOrderPlacementSession()
        XCTAssertTrue(session.phase.canStartPlacement)

        session.beginPlacing(Self.sampleSnapshot(intentId: "intent-a"))
        XCTAssertFalse(session.phase.canStartPlacement)

        session.completeFailure(.validationError("Test"))
        XCTAssertTrue(session.phase.canStartPlacement)
    }

    func testAcknowledgeFailure_clearsIntentForFreshRetry() {
        var session = BuyOrderPlacementSession()
        let firstIntent = session.ensureClientOrderIntentId()
        session.beginPlacing(Self.sampleSnapshot(intentId: firstIntent))
        session.completeFailure(.validationError("ABORTED replay"))

        XCTAssertEqual(session.pendingClientOrderIntentId, firstIntent)

        session.acknowledgeFailure()

        XCTAssertNil(session.pendingClientOrderIntentId)
        XCTAssertTrue(session.phase.isEditing)

        let secondIntent = session.ensureClientOrderIntentId()
        XCTAssertNotEqual(firstIntent, secondIntent)
    }

    func testFailedPhase_retryRotatesClientOrderIntentId() {
        var session = BuyOrderPlacementSession()
        let firstIntent = session.ensureClientOrderIntentId()
        session.beginPlacing(Self.sampleSnapshot(intentId: firstIntent))
        session.completeFailure(.validationError("Paired execution ABORTED"))

        XCTAssertTrue(session.phase.isFailed)
        XCTAssertEqual(session.pendingClientOrderIntentId, firstIntent)

        session.acknowledgeFailure()
        let retryIntent = session.ensureClientOrderIntentId()

        XCTAssertNotEqual(firstIntent, retryIntent)
    }

    private static func sampleSnapshot(intentId: String) -> BuyOrderPlacementSnapshot {
        BuyOrderPlacementSnapshot(
            quantity: 100,
            searchResult: SearchResult(
                valuationDate: "2026-06-29",
                wkn: "TEST123",
                strike: "100",
                askPrice: "1,50",
                direction: "Call",
                category: "Optionsschein",
                underlyingType: "Index",
                isin: "DE000TEST123",
                underlyingAsset: "DAX",
                denomination: 1,
                subscriptionRatio: 0.1,
                minimumOrderAmount: 1_000
            ),
            orderMode: .market,
            limit: "",
            priceValidityProgress: 1.0,
            investmentOrderCalculation: nil,
            clientOrderIntentId: intentId
        )
    }
}
