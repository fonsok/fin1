import Foundation
import Combine

// MARK: - Market Data Service Protocol
/// Protocol for managing real-time market data (stock prices, indices, etc.)
protocol MarketDataServiceProtocol: ObservableObject {
    /// Gets current market data for a symbol
    func getMarketData(for symbol: String) -> MarketData?

    /// Gets current market price for a symbol
    func getMarketPrice(for symbol: String) -> Double?

    /// Subscribes to market data updates for specific symbols
    func subscribeToMarketData(symbols: [String]) async

    /// Unsubscribes from market data updates
    func unsubscribeFromMarketData()
}

// MARK: - Market Data Service Implementation
/// Service for managing real-time market data with Live Query support
final class MarketDataService: MarketDataServiceProtocol {

    // MARK: - Published Properties

    @Published private(set) var marketDataCache: [String: MarketData] = [:] // symbol -> MarketData
    @Published private(set) var priceCache: [String: Double] = [:] // symbol -> price

    // MARK: - Dependencies

    private let parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?
    private let parseAPIClient: (any ParseAPIClientProtocol)?
    private var liveQuerySubscriptions: [String: LiveQuerySubscription] = [:] // symbol -> subscription
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        parseLiveQueryClient: (any ParseLiveQueryClientProtocol)? = nil,
        parseAPIClient: (any ParseAPIClientProtocol)? = nil
    ) {
        self.parseLiveQueryClient = parseLiveQueryClient
        self.parseAPIClient = parseAPIClient
        setupNotificationObserver()
    }

    // MARK: - MarketDataServiceProtocol

    func getMarketData(for symbol: String) -> MarketData? {
        return marketDataCache[symbol]
    }

    func getMarketPrice(for symbol: String) -> Double? {
        // First try cache
        if let cachedPrice = priceCache[symbol] {
            return cachedPrice
        }

        // Fallback to MarketPriceService for backward compatibility
        return MarketPriceService.getMarketPrice(for: symbol)
    }

    func subscribeToMarketData(symbols: [String]) async {
        guard let liveQueryClient = parseLiveQueryClient else {
            // Fallback to static data if Live Query is not available
            loadStaticMarketData(for: symbols)
            return
        }

        // Unsubscribe from previous subscriptions
        unsubscribeFromMarketData()

        // Subscribe to each symbol
        for symbol in symbols {
            await subscribeToSymbol(symbol, liveQueryClient: liveQueryClient)
        }
    }

    func unsubscribeFromMarketData() {
        for (symbol, subscription) in liveQuerySubscriptions {
            parseLiveQueryClient?.unsubscribe(subscription)
            print("📊 MarketDataService: Unsubscribed from Live Query for symbol \(symbol)")
        }
        liveQuerySubscriptions.removeAll()
    }

    // MARK: - Private Methods

    private func setupNotificationObserver() {
        // Observe Parse Live Query updates for MarketData
        NotificationCenter.default.publisher(for: .parseLiveQueryObjectUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let className = userInfo["className"] as? String,
                      className == "MarketData",
                      let object = userInfo["object"] as? [String: Any],
                      let symbol = object["symbol"] as? String else {
                    return
                }

                // Update market data cache
                Task { @MainActor in
                    await self.updateMarketDataFromParseObject(object, symbol: symbol)
                }
            }
            .store(in: &cancellables)
    }

    private func subscribeToSymbol(_ symbol: String, liveQueryClient: any ParseLiveQueryClientProtocol) async {
        // Subscribe to MarketData updates for this symbol
        let subscription = liveQueryClient.subscribe(
            className: "MarketData",
            query: ["symbol": symbol],
            onUpdate: { [weak self] (parseMarketData: ParseMarketData) in
                Task { @MainActor in
                    self?.updateMarketData(parseMarketData)
                }
            },
            onDelete: { (_ objectId: String) in
                // Market data deleted - could reload from server
                Task { @MainActor in
                    // Could reload from server here if needed
                }
            },
            onError: { error in
                print("⚠️ Live Query error for MarketData (symbol \(symbol)): \(error.localizedDescription)")
            }
        )
        liveQuerySubscriptions[symbol] = subscription
        print("📊 MarketDataService: Subscribed to Live Query for symbol \(symbol)")
    }

    private func updateMarketData(_ parseMarketData: ParseMarketData) {
        let marketData = parseMarketData.toMarketData()
        marketDataCache[parseMarketData.symbol] = marketData
        priceCache[parseMarketData.symbol] = parseMarketData.price

        print("📊 MarketDataService: Updated market data for \(parseMarketData.symbol): €\(parseMarketData.price.formatted(.currency(code: "EUR")))")

        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .marketDataDidUpdate,
            object: nil,
            userInfo: [
                "symbol": parseMarketData.symbol,
                "price": parseMarketData.price,
                "changePercent": parseMarketData.changePercent
            ]
        )
    }

    private func updateMarketDataFromParseObject(_ object: [String: Any], symbol: String) async {
        // Try to decode ParseMarketData from object
        guard let jsonData = try? JSONSerialization.data(withJSONObject: object),
              let parseMarketData = try? JSONDecoder().decode(ParseMarketData.self, from: jsonData) else {
            return
        }

        updateMarketData(parseMarketData)
    }

    private func loadStaticMarketData(for symbols: [String]) {
        // Fallback to static MarketPriceService data
        for symbol in symbols {
            let marketData = MarketPriceService.getMarketData(for: symbol)
            marketDataCache[symbol] = marketData
            priceCache[symbol] = MarketPriceService.getMarketPrice(for: symbol)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let marketDataDidUpdate = Notification.Name("marketDataDidUpdate")
}
