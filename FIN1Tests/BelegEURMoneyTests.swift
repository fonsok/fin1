@testable import FIN1
import XCTest

final class BelegEURMoneyTests: XCTestCase {

    func testDecodesJSONDoubleCentNormalized() throws {
        let json = #"{"amount":1095.4200000001}"#
        struct Wrapper: Decodable { let amount: BelegEURMoney }
        let decoded = try JSONDecoder().decode(Wrapper.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.amount.doubleValue, 1_095.42, accuracy: 0.0001)
        XCTAssertEqual(decoded.amount.decimal, Decimal(string: "1095.42")!)
    }

    func testDecodesJSONStringEUR() throws {
        let json = #"{"amount":"1.095,42"}"#
        struct Wrapper: Decodable { let amount: BelegEURMoney }
        let decoded = try JSONDecoder().decode(Wrapper.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.amount.doubleValue, 1_095.42, accuracy: 0.0001)
    }

    func testPrefersAmountCentsWhenPresent() throws {
        let json = """
        {
          "belegSchemaVersion": 1,
          "executionType": "sell",
          "amount": 999.99,
          "amountCents": 109542,
          "quantity": 400,
          "totalWithFees": 1087.92,
          "fees": { "totalFees": 7.5, "orderFee": 5 }
        }
        """
        let decoded = try JSONDecoder().decode(TraderCollectionBillBelegMetadata.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.amount?.doubleValue ?? 0, 1_095.42, accuracy: 0.0001)
    }

    func testBackendCollectionBillMetadataDecodesMoneyFields() throws {
        let json = """
        {
          "grossProfit": 419.95,
          "commission": 46.19,
          "buyLeg": {
            "amount": 1000,
            "fees": { "totalFees": 10 }
          }
        }
        """
        let decoded = try JSONDecoder().decode(BackendCollectionBillMetadata.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.grossProfit?.doubleValue ?? 0, 419.95, accuracy: 0.0001)
        XCTAssertEqual(decoded.buyLeg?.amount?.doubleValue ?? 0, 1_000, accuracy: 0.0001)
        XCTAssertEqual(decoded.buyLeg?.fees?.totalFees?.doubleValue ?? 0, 10, accuracy: 0.0001)
    }
}
