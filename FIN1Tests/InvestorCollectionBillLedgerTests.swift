@testable import FIN1
import XCTest

final class InvestorCollectionBillLedgerTests: XCTestCase {

    func testBelegReconciliationConsistentWhenMetadataMatchesLegs() {
        let metadata = BackendCollectionBillMetadata(
            ownershipPercentage: 100,
            grossProfit: BelegEURMoney(euro: 295.67),
            commission: BelegEURMoney(euro: 29.57),
            netProfit: BelegEURMoney(euro: 266.10),
            transferAmount: BelegEURMoney(euro: 1_265.90),
            residualAmount: BelegEURMoney(euro: 0),
            investmentNominal: BelegEURMoney(euro: 999.80),
            poolTradingAmount: BelegEURMoney(euro: 999.80),
            totalBuyCost: BelegEURMoney(euro: 999.80),
            netSellAmount: BelegEURMoney(euro: 1_295.47),
            returnPercentage: 29.92,
            commissionRate: 0.10,
            buyLeg: BackendCollectionBillLeg(
                quantity: 261,
                price: 3.80,
                amount: BelegEURMoney(euro: 991.80),
                fees: BackendFeeBreakdown(
                    orderFee: BelegEURMoney(euro: 5),
                    exchangeFee: BelegEURMoney(euro: 0.5),
                    foreignCosts: BelegEURMoney(euro: 2.5),
                    totalFees: BelegEURMoney(euro: 8)
                ),
                residualAmount: BelegEURMoney(euro: 0)
            ),
            sellLeg: BackendCollectionBillLeg(
                quantity: 261,
                price: 5.00,
                amount: BelegEURMoney(euro: 1_305.00),
                fees: BackendFeeBreakdown(
                    orderFee: BelegEURMoney(euro: 6.53),
                    exchangeFee: BelegEURMoney(euro: 0.5),
                    foreignCosts: BelegEURMoney(euro: 2.5),
                    totalFees: BelegEURMoney(euro: 9.53)
                ),
                residualAmount: nil
            )
        )
        let ledger = InvestorCollectionBillLedger.fromBackendLegs(
            buyAmount: 991.80,
            buyFees: 8,
            sellAmount: 1_305,
            sellFeesMagnitude: 9.53
        )
        let reconciliation = InvestorCollectionBillBelegReconciliation.reconcile(
            ledgerFromLegs: ledger,
            metadata: metadata
        )
        XCTAssertTrue(reconciliation.isConsistent)
        XCTAssertNil(reconciliation.inconsistencyMessage)
        XCTAssertEqual(reconciliation.displayGrossProfit, 295.67, accuracy: 0.0001)
    }

    func testBelegReconciliationFlagsGrossProfitDrift() {
        let metadata = BackendCollectionBillMetadata(
            ownershipPercentage: nil,
            grossProfit: BelegEURMoney(euro: 999),
            commission: nil,
            netProfit: nil,
            transferAmount: nil,
            residualAmount: nil,
            investmentNominal: nil,
            poolTradingAmount: nil,
            totalBuyCost: nil,
            netSellAmount: nil,
            returnPercentage: nil,
            commissionRate: nil,
            buyLeg: BackendCollectionBillLeg(
                quantity: 261,
                price: 3.80,
                amount: BelegEURMoney(euro: 991.80),
                fees: BackendFeeBreakdown(
                    orderFee: nil,
                    exchangeFee: nil,
                    foreignCosts: nil,
                    totalFees: BelegEURMoney(euro: 8)
                ),
                residualAmount: nil
            ),
            sellLeg: BackendCollectionBillLeg(
                quantity: 261,
                price: 5.00,
                amount: BelegEURMoney(euro: 1_305.00),
                fees: BackendFeeBreakdown(
                    orderFee: nil,
                    exchangeFee: nil,
                    foreignCosts: nil,
                    totalFees: BelegEURMoney(euro: 9.53)
                ),
                residualAmount: nil
            )
        )
        let ledger = InvestorCollectionBillLedger.fromBackendLegs(
            buyAmount: 991.80,
            buyFees: 8,
            sellAmount: 1_305,
            sellFeesMagnitude: 9.53
        )
        let reconciliation = InvestorCollectionBillBelegReconciliation.reconcile(
            ledgerFromLegs: ledger,
            metadata: metadata
        )
        XCTAssertFalse(reconciliation.isConsistent)
        XCTAssertNotNil(reconciliation.inconsistencyMessage)
        XCTAssertEqual(reconciliation.displayGrossProfit, 999, accuracy: 0.0001)
    }

    func testUserReportedMirrorTradeNumbers() {
        let ledger = InvestorCollectionBillLedger.fromBackendLegs(
            buyAmount: 991.80,
            buyFees: 8.00,
            sellAmount: 1_305.00,
            sellFeesMagnitude: 9.53
        )
        XCTAssertEqual(ledger.totalBuyCost, 999.80, accuracy: 0.0001)
        XCTAssertEqual(ledger.netSellAmount, 1_295.47, accuracy: 0.0001)
        XCTAssertEqual(ledger.grossProfit, 295.67, accuracy: 0.0001)
        XCTAssertEqual(ledger.sellFeesSigned, -9.53, accuracy: 0.0001)
    }

    func testBackendIndexKeepsNewestBillPerTrade() {
        let bills = [
            BackendCollectionBill(
                objectId: "a",
                userId: nil,
                type: nil,
                investmentId: "inv",
                tradeId: "t1",
                tradeNumber: 1,
                accountingDocumentNumber: nil,
                source: nil,
                metadata: nil,
                createdAt: "2026-05-16T10:00:00Z"
            ),
            BackendCollectionBill(
                objectId: "b",
                userId: nil,
                type: nil,
                investmentId: "inv",
                tradeId: "t1",
                tradeNumber: 1,
                accountingDocumentNumber: nil,
                source: nil,
                metadata: nil,
                createdAt: "2026-05-15T10:00:00Z"
            )
        ]
        let index = InvestorCollectionBillBackendIndex.billsByTradeId(bills)
        XCTAssertEqual(index["t1"]?.objectId, "a")
    }
}
