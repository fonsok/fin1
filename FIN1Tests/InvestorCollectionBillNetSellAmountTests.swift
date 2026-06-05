@testable import FIN1
import XCTest

/// Regression: Net Sell Amount = Sell Amount − |Sell Fees| (not Sell Amount + Sell Fees).
@MainActor
final class InvestorCollectionBillNetSellAmountTests: XCTestCase {

    func testNetSellAmountSubtractsFeeMagnitude() {
        let sellAmount = 1_305.00
        let sellFeesMagnitude = 9.53

        XCTAssertEqual(
            InvestorCollectionBillCalculationService.netSellAmount(
                securitiesAmount: sellAmount,
                sellFees: sellFeesMagnitude
            ),
            1_295.47,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            InvestorCollectionBillCalculationService.netSellAmount(
                securitiesAmount: sellAmount,
                sellFees: -sellFeesMagnitude
            ),
            1_295.47,
            accuracy: 0.0001
        )
    }

    func testGrossProfitEqualsNetSellMinusTotalBuyCost() {
        let netSell = 1_295.47
        let totalBuyCost = 999.80
        XCTAssertEqual(netSell - totalBuyCost, 295.67, accuracy: 0.0001)
    }

    func testStatementItemNetSellAmountMatchesSchema() {
        let ledger = InvestorCollectionBillLedger.fromBackendLegs(
            buyAmount: 991.80,
            buyFees: 8.00,
            sellAmount: 1_305.00,
            sellFeesMagnitude: 9.53
        )
        let item = InvestorInvestmentStatementItem(
            id: "trade-1",
            tradeNumber: 1,
            symbol: "ABC",
            tradeDate: Date(),
            buyQuantity: 261,
            buyPrice: 3.80,
            buyTotal: 991.80,
            buyFees: 8.00,
            buyFeeDetails: [],
            sellQuantity: 261,
            sellAveragePrice: 5.00,
            sellTotal: 1_305.00,
            sellFees: ledger.sellFeesSigned,
            sellFeeDetails: [],
            totalBuyCost: ledger.totalBuyCost,
            netSellAmount: ledger.netSellAmount,
            grossProfit: ledger.grossProfit,
            ownershipPercentage: 1.0,
            roiGrossProfit: 0,
            roiInvestedAmount: 0,
            tradeROI: 0.2992,
            commission: 29.57,
            grossProfitAfterCommission: 266.10,
            transferAmount: 1_265.90,
            residualAmount: 0,
            accountingDocumentNumber: "CB-2026-0000008",
            belegInconsistencyMessage: nil,
            isProvisionalLocalEstimate: false
        )

        XCTAssertEqual(item.netSellAmount, 1_295.47, accuracy: 0.0001)
        XCTAssertEqual(item.totalBuyCost, 999.80, accuracy: 0.0001)
        XCTAssertEqual(item.grossProfit, item.netSellAmount - item.totalBuyCost, accuracy: 0.0001)
    }
}
