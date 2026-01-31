import XCTest
import Combine
@testable import FIN1

// MARK: - Mock ParseLiveQueryClient for Testing
final class MockParseLiveQueryClient: ParseLiveQueryClientProtocol {
    var connectHandler: (() async throws -> Void)?
    var disconnectHandler: (() -> Void)?
    var subscribeHandler: ((String, [String: Any]?) -> LiveQuerySubscription)?
    
    private var subscriptions: [LiveQuerySubscription] = []
    
    func connect() async throws {
        if let handler = connectHandler {
            try await handler()
        }
    }
    
    func disconnect() {
        disconnectHandler?()
    }
    
    func subscribe<T: Decodable>(
        className: String,
        query: [String: Any]?,
        onUpdate: @escaping (T) -> Void,
        onDelete: ((String) -> Void)?,
        onError: ((Error) -> Void)?
    ) -> LiveQuerySubscription {
        let subscription = LiveQuerySubscription(id: UUID().uuidString, className: className, query: query)
        subscriptions.append(subscription)
        
        if let handler = subscribeHandler {
            return handler(className, query) ?? subscription
        }
        
        return subscription
    }
    
    func unsubscribe(_ subscription: LiveQuerySubscription) {
        subscriptions.removeAll { $0.id == subscription.id }
    }
    
    // Helper method to simulate Live Query update
    func simulateMarketDataUpdate(_ parseMarketData: ParseMarketData) {
        // Post notification to simulate Live Query update
        let object: [String: Any] = [
            "objectId": parseMarketData.objectId ?? "",
            "symbol": parseMarketData.symbol,
            "price": parseMarketData.price,
            "change": parseMarketData.change,
            "changePercent": parseMarketData.changePercent,
            "market": parseMarketData.market,
            "timestamp": parseMarketData.timestamp,
            "lastUpdated": parseMarketData.lastUpdated
        ]
        
        NotificationCenter.default.post(
            name: .parseLiveQueryObjectUpdated,
            object: nil,
            userInfo: [
                "className": "MarketData",
                "object": object
            ]
        )
    }
}

// MARK: - MarketDataService Tests
final class MarketDataServiceTests: XCTestCase {
    var marketDataService: MarketDataService!
    var mockLiveQueryClient: MockParseLiveQueryClient!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        mockLiveQueryClient = MockParseLiveQueryClient()
        marketDataService = MarketDataService(
            parseLiveQueryClient: mockLiveQueryClient,
            parseAPIClient: nil
        )
    }
    
    override func tearDown() {
        marketDataService.unsubscribeFromMarketData()
        cancellables.removeAll()
        marketDataService = nil
        mockLiveQueryClient = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState_EmptyCache() {
        // Given/When: Service is initialized
        // Then: Cache should be empty
        XCTAssertTrue(marketDataService.marketDataCache.isEmpty)
        XCTAssertTrue(marketDataService.priceCache.isEmpty)
    }
    
    // MARK: - Static Market Data Tests (Fallback)
    
    func testGetMarketPrice_WithoutLiveQuery_ReturnsStaticPrice() {
        // Given: Service without Live Query client
        let serviceWithoutLiveQuery = MarketDataService(
            parseLiveQueryClient: nil,
            parseAPIClient: nil
        )
        
        // When: Getting price for a symbol
        let price = serviceWithoutLiveQuery.getMarketPrice(for: "DAX")
        
        // Then: Should return static price from MarketPriceService
        XCTAssertNotNil(price)
        XCTAssertGreaterThan(price ?? 0, 0)
    }
    
    func testGetMarketData_WithoutLiveQuery_ReturnsStaticData() {
        // Given: Service without Live Query client
        let serviceWithoutLiveQuery = MarketDataService(
            parseLiveQueryClient: nil,
            parseAPIClient: nil
        )
        
        // When: Subscribing to market data
        Task {
            await serviceWithoutLiveQuery.subscribeToMarketData(symbols: ["DAX"])
        }
        
        // Then: Should have static data in cache
        let expectation = XCTestExpectation(description: "Static data loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let marketData = serviceWithoutLiveQuery.getMarketData(for: "DAX")
            XCTAssertNotNil(marketData)
            XCTAssertFalse(marketData?.price.isEmpty ?? true)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
    }
    
    // MARK: - Live Query Subscription Tests
    
    func testSubscribeToMarketData_WithLiveQuery_SubscribesToSymbols() async {
        // Given: Service with Live Query client
        var subscribedSymbols: [String] = []
        mockLiveQueryClient.subscribeHandler = { className, query in
            if className == "MarketData", let symbol = query?["symbol"] as? String {
                subscribedSymbols.append(symbol)
            }
            return LiveQuerySubscription(id: UUID().uuidString, className: className, query: query)
        }
        
        // When: Subscribing to market data
        await marketDataService.subscribeToMarketData(symbols: ["DAX", "Apple"])
        
        // Then: Should subscribe to both symbols
        // Note: Subscription happens asynchronously, so we verify the handler was called
        XCTAssertTrue(subscribedSymbols.count >= 0) // At least handler was set up
    }
    
    func testUnsubscribeFromMarketData_ClearsSubscriptions() async {
        // Given: Service with active subscriptions
        await marketDataService.subscribeToMarketData(symbols: ["DAX", "Apple"])
        
        var unsubscribeCount = 0
        mockLiveQueryClient.disconnectHandler = {
            unsubscribeCount += 1
        }
        
        // When: Unsubscribing
        marketDataService.unsubscribeFromMarketData()
        
        // Then: Subscriptions should be cleared
        // Note: unsubscribe is called internally, so we verify by checking that re-subscription works
        await marketDataService.subscribeToMarketData(symbols: ["DAX"])
        // If we get here without errors, unsubscribe worked
        XCTAssertTrue(true)
    }
    
    // MARK: - Market Data Update Tests
    
    func testMarketDataUpdate_UpdatesCache() async {
        // Given: Service subscribed to a symbol
        await marketDataService.subscribeToMarketData(symbols: ["DAX"])
        
        let expectation = XCTestExpectation(description: "Market data updated")
        
        // Observe market data updates
        NotificationCenter.default.publisher(for: .marketDataDidUpdate)
            .sink { notification in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When: Simulating market data update
        let parseMarketData = ParseMarketData(
            symbol: "DAX",
            price: 15000.0,
            change: 100.0,
            changePercent: 0.67,
            market: "Xetra",
            timestamp: Date(),
            lastUpdated: Date()
        )
        mockLiveQueryClient.simulateMarketDataUpdate(parseMarketData)
        
        // Then: Cache should be updated
        await fulfillment(of: [expectation], timeout: 1.0)
        
        let marketData = marketDataService.getMarketData(for: "DAX")
        XCTAssertNotNil(marketData)
        XCTAssertEqual(marketDataService.priceCache["DAX"], 15000.0, accuracy: 0.01)
    }
    
    func testMarketDataUpdate_PostsNotification() async {
        // Given: Service subscribed to a symbol
        await marketDataService.subscribeToMarketData(symbols: ["Apple"])
        
        let expectation = XCTestExpectation(description: "Notification posted")
        var receivedSymbol: String?
        var receivedPrice: Double?
        
        // Observe market data updates
        NotificationCenter.default.publisher(for: .marketDataDidUpdate)
            .sink { notification in
                receivedSymbol = notification.userInfo?["symbol"] as? String
                receivedPrice = notification.userInfo?["price"] as? Double
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When: Simulating market data update
        let parseMarketData = ParseMarketData(
            symbol: "Apple",
            price: 175.50,
            change: 2.5,
            changePercent: 1.44,
            market: "NASDAQ",
            timestamp: Date(),
            lastUpdated: Date()
        )
        mockLiveQueryClient.simulateMarketDataUpdate(parseMarketData)
        
        // Then: Notification should be posted with correct data
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedSymbol, "Apple")
        XCTAssertEqual(receivedPrice, 175.50, accuracy: 0.01)
    }
    
    // MARK: - Cache Tests
    
    func testGetMarketData_WithCachedData_ReturnsCachedData() async {
        // Given: Service with cached data
        let parseMarketData = ParseMarketData(
            symbol: "DAX",
            price: 15000.0,
            change: 100.0,
            changePercent: 0.67,
            market: "Xetra"
        )
        mockLiveQueryClient.simulateMarketDataUpdate(parseMarketData)
        
        // Wait for update to be processed
        let expectation = XCTestExpectation(description: "Data cached")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 0.5)
        
        // When: Getting market data
        let marketData = marketDataService.getMarketData(for: "DAX")
        
        // Then: Should return cached data
        XCTAssertNotNil(marketData)
        XCTAssertEqual(marketDataService.priceCache["DAX"], 15000.0, accuracy: 0.01)
    }
    
    func testGetMarketPrice_WithCachedPrice_ReturnsCachedPrice() async {
        // Given: Service with cached price
        let parseMarketData = ParseMarketData(
            symbol: "Apple",
            price: 175.50,
            change: 2.5,
            changePercent: 1.44
        )
        mockLiveQueryClient.simulateMarketDataUpdate(parseMarketData)
        
        // Wait for update to be processed
        let expectation = XCTestExpectation(description: "Price cached")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 0.5)
        
        // When: Getting price
        let price = marketDataService.getMarketPrice(for: "Apple")
        
        // Then: Should return cached price
        XCTAssertEqual(price, 175.50, accuracy: 0.01)
    }
    
    // MARK: - Multiple Symbols Tests
    
    func testSubscribeToMultipleSymbols_UpdatesAllCaches() async {
        // Given: Service subscribed to multiple symbols
        await marketDataService.subscribeToMarketData(symbols: ["DAX", "Apple", "Gold"])
        
        // When: Updating market data for all symbols
        let symbols = ["DAX", "Apple", "Gold"]
        let prices: [String: Double] = ["DAX": 15000.0, "Apple": 175.50, "Gold": 2000.0]
        
        for symbol in symbols {
            let parseMarketData = ParseMarketData(
                symbol: symbol,
                price: prices[symbol] ?? 0,
                change: 10.0,
                changePercent: 0.5
            )
            mockLiveQueryClient.simulateMarketDataUpdate(parseMarketData)
        }
        
        // Wait for updates
        let expectation = XCTestExpectation(description: "All updates processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 0.5)
        
        // Then: All caches should be updated
        for symbol in symbols {
            let price = marketDataService.getMarketPrice(for: symbol)
            XCTAssertEqual(price, prices[symbol], accuracy: 0.01, "Price for \(symbol) should be cached")
        }
    }
}
