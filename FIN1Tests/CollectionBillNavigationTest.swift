import XCTest
@testable import FIN1

@MainActor
final class CollectionBillNavigationTest: XCTestCase {

    func testCollectionBillNavigationDebugging() async {
        // This test verifies that the debugging output works when trying to navigate to Collection Bill
        // from notifications by trade number

        // Create a mock trade number
        let tradeNumber = 288

        // Create the wrapper that would be used in notifications
        let wrapper = CollectionBillByNumberViewWrapper(tradeNumber: tradeNumber)

        // The wrapper should be created successfully
        XCTAssertNotNil(wrapper)

        // The trade number should be set correctly
        XCTAssertEqual(wrapper.tradeNumber, tradeNumber)

        // This test mainly verifies that the debugging code compiles and runs
        // The actual debugging output will be visible when running the app
        print("✅ CollectionBillNavigationTest: Wrapper created successfully for trade #\(tradeNumber)")
    }

    func testTradeNumberExtraction() {
        // Test the trade number extraction from document name
        // Using the actual document naming format: "CollectionBill_Trade1_20251023_L8PDJS5H.pdf"
        let documentName = "CollectionBill_Trade288_20251023_L8PDJS5H.pdf"
        let pattern = #"Trade(\d+)"#

        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: documentName, range: NSRange(documentName.startIndex..., in: documentName)),
           let range = Range(match.range(at: 1), in: documentName) {
            let tradeNumber = Int(String(documentName[range]))
            XCTAssertEqual(tradeNumber, 288)
            print("✅ Trade number extraction works: \(tradeNumber ?? -1)")
        } else {
            XCTFail("Failed to extract trade number from document name")
        }
    }
}
