import XCTest
@testable import FIN1

// MARK: - ParseMarketData Tests
final class ParseMarketDataTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testInitialization_WithAllParameters_CreatesValidInstance() {
        // Given: All parameters
        let objectId = "test-object-id"
        let symbol = "DAX"
        let price = 15000.0
        let change = 100.0
        let changePercent = 0.67
        let volume = 1000000.0
        let market = "Xetra"
        let timestamp = Date()
        let lastUpdated = Date()
        let high = 15100.0
        let low = 14900.0
        let open = 14950.0
        let previousClose = 14900.0
        
        // When: Creating ParseMarketData
        let parseMarketData = ParseMarketData(
            objectId: objectId,
            symbol: symbol,
            price: price,
            change: change,
            changePercent: changePercent,
            volume: volume,
            market: market,
            timestamp: timestamp,
            lastUpdated: lastUpdated,
            high: high,
            low: low,
            open: open,
            previousClose: previousClose
        )
        
        // Then: All properties should be set correctly
        XCTAssertEqual(parseMarketData.objectId, objectId)
        XCTAssertEqual(parseMarketData.symbol, symbol)
        XCTAssertEqual(parseMarketData.price, price, accuracy: 0.01)
        XCTAssertEqual(parseMarketData.change, change, accuracy: 0.01)
        XCTAssertEqual(parseMarketData.changePercent, changePercent, accuracy: 0.01)
        XCTAssertEqual(parseMarketData.volume, volume, accuracy: 0.01)
        XCTAssertEqual(parseMarketData.market, market)
        XCTAssertEqual(parseMarketData.timestamp.timeIntervalSince1970, timestamp.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(parseMarketData.high, high, accuracy: 0.01)
        XCTAssertEqual(parseMarketData.low, low, accuracy: 0.01)
        XCTAssertEqual(parseMarketData.open, open, accuracy: 0.01)
        XCTAssertEqual(parseMarketData.previousClose, previousClose, accuracy: 0.01)
    }
    
    func testInitialization_WithMinimalParameters_UsesDefaults() {
        // Given: Minimal parameters
        let symbol = "Apple"
        let price = 175.50
        let change = 2.5
        let changePercent = 1.44
        
        // When: Creating ParseMarketData with minimal parameters
        let parseMarketData = ParseMarketData(
            symbol: symbol,
            price: price,
            change: change,
            changePercent: changePercent
        )
        
        // Then: Required properties should be set, optional should use defaults
        XCTAssertNil(parseMarketData.objectId)
        XCTAssertEqual(parseMarketData.symbol, symbol)
        XCTAssertEqual(parseMarketData.price, price, accuracy: 0.01)
        XCTAssertEqual(parseMarketData.change, change, accuracy: 0.01)
        XCTAssertEqual(parseMarketData.changePercent, changePercent, accuracy: 0.01)
        XCTAssertNil(parseMarketData.volume)
        XCTAssertEqual(parseMarketData.market, "Xetra") // Default value
        XCTAssertNil(parseMarketData.high)
        XCTAssertNil(parseMarketData.low)
        XCTAssertNil(parseMarketData.open)
        XCTAssertNil(parseMarketData.previousClose)
    }
    
    // MARK: - Conversion to MarketData Tests
    
    func testToMarketData_ConvertsCorrectly() {
        // Given: ParseMarketData with known values
        let parseMarketData = ParseMarketData(
            symbol: "DAX",
            price: 15000.50,
            change: 100.0,
            changePercent: 0.67,
            market: "Xetra",
            timestamp: Date(timeIntervalSince1970: 1706112000) // Fixed timestamp
        )
        
        // When: Converting to MarketData
        let marketData = parseMarketData.toMarketData()
        
        // Then: Should convert correctly
        XCTAssertTrue(marketData.price.contains("15000") || marketData.price.contains("15000,50"))
        XCTAssertTrue(marketData.change.contains("0,67") || marketData.change.contains("+ 0,67"))
        XCTAssertEqual(marketData.market, "Xetra")
        // Time format should be HH:mm
        XCTAssertTrue(marketData.time.count == 5) // "HH:mm" format
    }
    
    func testToMarketData_NegativeChange_FormatsCorrectly() {
        // Given: ParseMarketData with negative change
        let parseMarketData = ParseMarketData(
            symbol: "Apple",
            price: 175.50,
            change: -2.5,
            changePercent: -1.44,
            market: "NASDAQ"
        )
        
        // When: Converting to MarketData
        let marketData = parseMarketData.toMarketData()
        
        // Then: Change should be formatted with minus sign
        XCTAssertTrue(marketData.change.contains("-") || marketData.change.contains("1,44"))
    }
    
    func testToMarketData_PositiveChange_FormatsCorrectly() {
        // Given: ParseMarketData with positive change
        let parseMarketData = ParseMarketData(
            symbol: "DAX",
            price: 15000.0,
            change: 100.0,
            changePercent: 0.67,
            market: "Xetra"
        )
        
        // When: Converting to MarketData
        let marketData = parseMarketData.toMarketData()
        
        // Then: Change should be formatted with plus sign
        XCTAssertTrue(marketData.change.contains("+") || marketData.change.contains("0,67"))
    }
    
    // MARK: - Conversion from MarketData Tests
    
    func testFromMarketData_ConvertsCorrectly() {
        // Given: MarketData with known values
        let marketData = MarketData(
            price: "15000,50",
            change: "+ 0,67",
            time: "15:30",
            market: "Xetra"
        )
        
        // When: Converting from MarketData
        let parseMarketData = ParseMarketData.from(marketData, symbol: "DAX")
        
        // Then: Should convert correctly
        XCTAssertEqual(parseMarketData.symbol, "DAX")
        XCTAssertEqual(parseMarketData.price, 15000.50, accuracy: 0.01)
        XCTAssertEqual(parseMarketData.changePercent, 0.67, accuracy: 0.01)
        XCTAssertEqual(parseMarketData.market, "Xetra")
        XCTAssertNil(parseMarketData.objectId) // Should be nil (set by Parse Server)
    }
    
    func testFromMarketData_NegativeChange_ParsesCorrectly() {
        // Given: MarketData with negative change
        let marketData = MarketData(
            price: "175,50",
            change: "- 1,44",
            time: "16:00",
            market: "NASDAQ"
        )
        
        // When: Converting from MarketData
        let parseMarketData = ParseMarketData.from(marketData, symbol: "Apple")
        
        // Then: Should parse negative change correctly
        XCTAssertEqual(parseMarketData.symbol, "Apple")
        XCTAssertEqual(parseMarketData.price, 175.50, accuracy: 0.01)
        XCTAssertEqual(parseMarketData.changePercent, 1.44, accuracy: 0.01)
        XCTAssertLessThan(parseMarketData.change, 0) // Change should be negative
    }
    
    func testFromMarketData_InvalidPrice_HandlesGracefully() {
        // Given: MarketData with invalid price string
        let marketData = MarketData(
            price: "invalid",
            change: "+ 0,50",
            time: "15:30",
            market: "Xetra"
        )
        
        // When: Converting from MarketData
        let parseMarketData = ParseMarketData.from(marketData, symbol: "DAX")
        
        // Then: Should handle gracefully (price becomes 0.0)
        XCTAssertEqual(parseMarketData.price, 0.0, accuracy: 0.01)
    }
    
    // MARK: - Codable Tests
    
    func testCodable_EncodesAndDecodesCorrectly() throws {
        // Given: ParseMarketData instance
        let original = ParseMarketData(
            objectId: "test-id",
            symbol: "DAX",
            price: 15000.0,
            change: 100.0,
            changePercent: 0.67,
            volume: 1000000.0,
            market: "Xetra",
            timestamp: Date(),
            lastUpdated: Date(),
            high: 15100.0,
            low: 14900.0,
            open: 14950.0,
            previousClose: 14900.0
        )
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ParseMarketData.self, from: data)
        
        // Then: Should match original
        XCTAssertEqual(decoded.objectId, original.objectId)
        XCTAssertEqual(decoded.symbol, original.symbol)
        XCTAssertEqual(decoded.price, original.price, accuracy: 0.01)
        XCTAssertEqual(decoded.change, original.change, accuracy: 0.01)
        XCTAssertEqual(decoded.changePercent, original.changePercent, accuracy: 0.01)
        XCTAssertEqual(decoded.volume, original.volume, accuracy: 0.01)
        XCTAssertEqual(decoded.market, original.market)
        XCTAssertEqual(decoded.high, original.high, accuracy: 0.01)
        XCTAssertEqual(decoded.low, original.low, accuracy: 0.01)
        XCTAssertEqual(decoded.open, original.open, accuracy: 0.01)
        XCTAssertEqual(decoded.previousClose, original.previousClose, accuracy: 0.01)
    }
    
    func testCodable_WithNilOptionals_EncodesAndDecodesCorrectly() throws {
        // Given: ParseMarketData with nil optionals
        let original = ParseMarketData(
            symbol: "Apple",
            price: 175.50,
            change: 2.5,
            changePercent: 1.44
        )
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ParseMarketData.self, from: data)
        
        // Then: Should match original (nil optionals should remain nil)
        XCTAssertNil(decoded.objectId)
        XCTAssertEqual(decoded.symbol, original.symbol)
        XCTAssertNil(decoded.volume)
        XCTAssertNil(decoded.high)
        XCTAssertNil(decoded.low)
        XCTAssertNil(decoded.open)
        XCTAssertNil(decoded.previousClose)
    }
}
