import Foundation

/// Ensures fresh Parse `MarketData` before market-order execution (feed-first, upsert fallback).
enum MarketDataQuotePublisher {

    private struct PublishResult: Decodable {
        let symbol: String
        let price: Double
        let publishedAt: String
    }

    private struct LatestMarketDataRow: Decodable {
        let symbol: String?
        let price: Double?
        let timestamp: ParseRESTDate?

        var quoteTimestamp: Date? {
            self.timestamp?.date
        }
    }

    private enum ParseRESTDate: Decodable {
        case isoString(String)
        case parseObject(iso: String)

        init(from decoder: Decoder) throws {
            if let single = try? decoder.singleValueContainer(),
               let value = try? single.decode(String.self) {
                self = .isoString(value)
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let iso = try container.decode(String.self, forKey: .iso)
            self = .parseObject(iso: iso)
        }

        private enum CodingKeys: String, CodingKey {
            case iso
        }

        var date: Date? {
            switch self {
            case .isoString(let value), .parseObject(let value):
                return Self.parseISO(value)
            }
        }

        private static func parseISO(_ raw: String) -> Date? {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: raw) {
                return date
            }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            return plain.date(from: raw)
        }
    }

    /// Uses server feed when fresh; otherwise publishes indicative UI quote via `upsertMarketDataQuote`.
    static func ensureFreshMarketDataBeforeExecution(
        symbol: String,
        indicativePrice: Double,
        via client: any ParseAPIClientProtocol,
        maxAgeSeconds: TimeInterval = CalculationConstants.ExecutionPricing.marketDataMaxAgeSeconds
    ) async throws {
        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSymbol.isEmpty else {
            throw AppError.validationError("Symbol fehlt für Marktkurs-Veröffentlichung.")
        }
        guard indicativePrice.isFinite, indicativePrice > 0 else {
            throw AppError.validationError("Ungültiger Anzeigekurs für Marktorder.")
        }

        if let quotedAt = try await fetchLatestQuoteTimestamp(symbol: trimmedSymbol, via: client),
           Date().timeIntervalSince(quotedAt) <= maxAgeSeconds {
            return
        }

        try await self.publishIndicativeQuote(
            symbol: trimmedSymbol,
            indicativePrice: indicativePrice,
            via: client
        )
    }

    private static func fetchLatestQuoteTimestamp(
        symbol: String,
        via client: any ParseAPIClientProtocol
    ) async throws -> Date? {
        let rows: [LatestMarketDataRow] = try await client.fetchObjects(
            className: "MarketData",
            query: ["symbol": symbol],
            include: nil,
            orderBy: "-timestamp",
            limit: 1
        )
        guard let row = rows.first,
              let price = row.price,
              price > 0,
              let quotedAt = row.quoteTimestamp else {
            return nil
        }
        return quotedAt
    }

    private static func publishIndicativeQuote(
        symbol: String,
        indicativePrice: Double,
        via client: any ParseAPIClientProtocol
    ) async throws {
        let _: PublishResult = try await client.callFunction(
            "upsertMarketDataQuote",
            parameters: [
                "symbol": symbol,
                "price": indicativePrice
            ]
        )
    }
}
