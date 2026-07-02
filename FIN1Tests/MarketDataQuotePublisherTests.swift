@testable import FIN1
import XCTest

final class MarketDataQuotePublisherTests: XCTestCase {

    private var mockClient: MockParseAPIClient!

    override func setUp() {
        super.setUp()
        self.mockClient = MockParseAPIClient()
    }

    override func tearDown() {
        self.mockClient = nil
        super.tearDown()
    }

    func testSkipsUpsertWhenFeedQuoteIsFresh() async throws {
        let iso = ISO8601DateFormatter().string(from: Date())
        self.mockClient.mockFetchResults = [
            [
                "symbol": "865985",
                "price": 174.0,
                "timestamp": ["iso": iso]
            ]
        ]

        try await MarketDataQuotePublisher.ensureFreshMarketDataBeforeExecution(
            symbol: "865985",
            indicativePrice: 180.0,
            via: self.mockClient
        )

        XCTAssertTrue(self.mockClient.fetchObjectsCalled)
        XCTAssertEqual(self.mockClient.lastClassName, "MarketData")
        XCTAssertFalse(self.mockClient.callFunctionCalled)
    }

    func testUpsertsWhenFeedQuoteMissing() async throws {
        self.mockClient.mockFetchResults = [[String: Any]]()

        try await MarketDataQuotePublisher.ensureFreshMarketDataBeforeExecution(
            symbol: "UNKNOWN-WKN",
            indicativePrice: 120.0,
            via: self.mockClient
        )

        XCTAssertTrue(self.mockClient.callFunctionCalled)
        XCTAssertEqual(self.mockClient.lastFunctionName, "upsertMarketDataQuote")
        XCTAssertEqual(self.mockClient.lastFunctionParameters?["symbol"] as? String, "UNKNOWN-WKN")
    }

    func testUpsertsWhenFeedQuoteStale() async throws {
        let stale = Calendar.current.date(byAdding: .minute, value: -10, to: Date())!
        let iso = ISO8601DateFormatter().string(from: stale)
        self.mockClient.mockFetchResults = [
            [
                "symbol": "865985",
                "price": 174.0,
                "timestamp": ["iso": iso]
            ]
        ]

        try await MarketDataQuotePublisher.ensureFreshMarketDataBeforeExecution(
            symbol: "865985",
            indicativePrice: 174.0,
            via: self.mockClient,
            maxAgeSeconds: 300
        )

        XCTAssertEqual(self.mockClient.lastFunctionName, "upsertMarketDataQuote")
    }
}
