import XCTest
@testable import FIN1

final class BackendCollectionBillMetadataDecodingTests: XCTestCase {

    func testDecodesReturnPercentageFromBackendMetadata() throws {
        let json = """
        {
          "ownershipPercentage": 35.7,
          "grossProfit": 419.95,
          "commission": 46.19,
          "netProfit": 373.76,
          "returnPercentage": 37.38,
          "commissionRate": 0.11,
          "buyLeg": {
            "quantity": 10,
            "price": 100,
            "amount": 1000,
            "fees": {
              "totalFees": 10
            }
          },
          "sellLeg": null
        }
        """

        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(BackendCollectionBillMetadata.self, from: data)

        XCTAssertNotNil(decoded.returnPercentage)
        XCTAssertEqual(decoded.returnPercentage ?? 0, 37.38, accuracy: 0.0001)
    }
}
