@testable import FIN1
import XCTest

final class TraderCommissionSettlementResolverTests: XCTestCase {
    func testPrefersCommissionClassRows() throws {
        let settlement = try Self.decodeSettlement(
            """
            {
              "tradeId": "t1",
              "grossProfit": 500,
              "totalFees": 12,
              "netProfit": 400,
              "status": "completed",
              "isSettledByBackend": true,
              "accountStatementEntries": [],
              "documents": [],
              "commissions": [
                {
                  "objectId": "c1",
                  "commissionAmount": 40
                }
              ]
            }
            """
        )
        XCTAssertEqual(TraderCommissionSettlementResolver.totalCommission(from: settlement), 40, accuracy: 0.01)
    }

    func testFallsBackToCommissionCreditStatement() throws {
        let settlement = try Self.decodeSettlement(
            """
            {
              "tradeId": "t1",
              "grossProfit": 500,
              "totalFees": 0,
              "netProfit": 400,
              "status": "completed",
              "isSettledByBackend": true,
              "accountStatementEntries": [
                {
                  "objectId": "s1",
                  "userId": "trader",
                  "entryType": "commission_credit",
                  "amount": 55.5,
                  "balanceBefore": 0,
                  "balanceAfter": 55.5,
                  "tradeId": "t1"
                }
              ],
              "documents": [],
              "commissions": []
            }
            """
        )
        XCTAssertEqual(TraderCommissionSettlementResolver.totalCommission(from: settlement), 55.5, accuracy: 0.01)
    }

    private static func decodeSettlement(_ json: String) throws -> TradeSettlementResponse {
        try JSONDecoder().decode(TradeSettlementResponse.self, from: Data(json.utf8))
    }
}
