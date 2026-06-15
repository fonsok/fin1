@testable import FIN1
import XCTest

final class DocumentTraderBelegDriftTests: XCTestCase {

    func testDetectsQuantityDriftBetweenSnapshotAndMetadata() {
        let meta = Self.makeMetadata(executionType: "sell", quantity: 1_200, amount: 996, totalWithFees: 988.5)
        let snapshot = """
        Verkaufsabrechnung
        VERKAUF
        Ordervolumen: 400 St.
        Kurswert: 996,00 €
        Σ VERKAUF: 988,50 €
        """
        let drifts = Document.traderBelegSnapshotMetadataDrifts(snapshotText: snapshot, metadata: meta)
        XCTAssertTrue(drifts.contains(.quantity))
    }

    func testNoDriftWhenAligned() {
        let meta = Self.makeMetadata(executionType: "sell", quantity: 400, amount: 996, totalWithFees: 988.5)
        let snapshot = """
        Verkaufsabrechnung
        VERKAUF
        Ordervolumen: 400 St.
        Kurswert: 996,00 €
        Σ VERKAUF: 988,50 €
        """
        let drifts = Document.traderBelegSnapshotMetadataDrifts(snapshotText: snapshot, metadata: meta)
        XCTAssertTrue(drifts.isEmpty)
    }

    private static func makeMetadata(
        executionType: String,
        quantity: Double,
        amount: Double,
        totalWithFees: Double
    ) -> TraderCollectionBillBelegMetadata {
        TraderCollectionBillBelegMetadata(
            belegSchemaVersion: 1,
            belegKind: "traderCollectionBill",
            belegLabel: nil,
            traderId: nil,
            traderDisplayName: "Trader",
            traderUsername: nil,
            executionType: executionType,
            symbol: "GS4GLEF",
            instrumentLine: nil,
            amount: amount,
            quantity: quantity,
            price: 2.49,
            orderId: nil,
            sellOrderId: nil,
            wkn: nil,
            fees: .init(orderFee: 5, exchangeFee: 1, foreignCosts: 1.5, totalFees: 7.5),
            totalWithFees: totalWithFees,
            valueDate: nil,
            closingDate: nil,
            tradingVenue: nil,
            tradeNumber: 1,
            tradeStatus: nil,
            generatedAt: nil,
            partialSell: nil
        )
    }
}
