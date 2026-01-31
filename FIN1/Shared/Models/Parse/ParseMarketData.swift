import Foundation

// MARK: - Parse Market Data Model
/// Represents Market Data (stock prices, indices, etc.) as stored in Parse Server
struct ParseMarketData: Codable {
    let objectId: String? // Parse Server generated ID
    let symbol: String // Stock symbol, index name, or underlying asset identifier
    let price: Double
    let change: Double // Price change amount
    let changePercent: Double // Price change percentage
    let volume: Double?
    let market: String // Exchange name (e.g., "Xetra", "NYSE")
    let timestamp: Date
    let lastUpdated: Date
    
    // Optional fields
    let high: Double? // Daily high
    let low: Double? // Daily low
    let open: Double? // Opening price
    let previousClose: Double? // Previous day's closing price
    
    // MARK: - Initialization
    
    init(
        objectId: String? = nil,
        symbol: String,
        price: Double,
        change: Double,
        changePercent: Double,
        volume: Double? = nil,
        market: String = "Xetra",
        timestamp: Date = Date(),
        lastUpdated: Date = Date(),
        high: Double? = nil,
        low: Double? = nil,
        open: Double? = nil,
        previousClose: Double? = nil
    ) {
        self.objectId = objectId
        self.symbol = symbol
        self.price = price
        self.change = change
        self.changePercent = changePercent
        self.volume = volume
        self.market = market
        self.timestamp = timestamp
        self.lastUpdated = lastUpdated
        self.high = high
        self.low = low
        self.open = open
        self.previousClose = previousClose
    }
    
    // MARK: - Conversion to MarketData
    
    func toMarketData() -> MarketData {
        let changeStr = String(format: "%@%.2f", changePercent >= 0 ? "+ " : "- ", abs(changePercent))
            .replacingOccurrences(of: ".", with: ",")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let timeStr = dateFormatter.string(from: timestamp)
        
        // Format price with German locale
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.locale = Locale(identifier: "de_DE")
        let priceStr = numberFormatter.string(for: price) ?? "0,00"
        
        return MarketData(
            price: priceStr,
            change: changeStr,
            time: timeStr,
            market: market
        )
    }
    
    // MARK: - Conversion from MarketData
    
    static func from(_ marketData: MarketData, symbol: String) -> ParseMarketData {
        // Parse price string back to Double
        let price = Double(marketData.price.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        
        // Parse change string to extract percentage
        let changeStr = marketData.change.replacingOccurrences(of: ",", with: ".")
        let changePercent = Double(changeStr.replacingOccurrences(of: "+ ", with: "").replacingOccurrences(of: "- ", with: "")) ?? 0.0
        let isPositive = marketData.change.contains("+")
        let change = isPositive ? changePercent : -changePercent
        
        // Parse time string to Date
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timestamp = formatter.date(from: marketData.time) ?? Date()
        
        return ParseMarketData(
            objectId: nil, // Will be set by Parse Server
            symbol: symbol,
            price: price,
            change: change,
            changePercent: changePercent,
            market: marketData.market,
            timestamp: timestamp,
            lastUpdated: Date()
        )
    }
}
