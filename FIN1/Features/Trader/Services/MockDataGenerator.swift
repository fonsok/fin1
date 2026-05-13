import Foundation

// MARK: - Mock Data Generator Protocol
protocol MockDataGeneratorProtocol {
    func generateSearchResults(for filters: SearchFilters) async throws -> [SearchResult]
    func generateMarketData(for underlyingAsset: String) -> SecuritiesSearchViewModel.MarketData
}

// MARK: - Mock Data Generator Implementation
class MockDataGenerator: MockDataGeneratorProtocol {

    func generateSearchResults(for filters: SearchFilters) async throws -> [SearchResult] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Generate results based on filter type
        if filters.category == "Aktie" {
            return self.generateStockResults(for: filters)
        } else {
            return self.generateOptionsResults(for: filters)
        }
    }

    func generateMarketData(for underlyingAsset: String) -> SecuritiesSearchViewModel.MarketData {
        // Generate deterministic market data based on underlyingAsset for consistency
        let seed = underlyingAsset.hash
        var rng = Int(truncatingIfNeeded: seed)
        rng = abs(rng == .min ? 0 : rng)

        // Generate price based on underlyingAsset type
        let price: Double
        switch underlyingAsset {
        case "DAX", "MDAX", "Dow Jones", "S&P 500", "NASDAQ 100", "Euro Stoxx 50", "FTSE 100", "CAC 40", "SMI":
            // Index prices (higher values)
            price = Double((rng % 4_000_000) + 1_000_000) / 100.0 // 10.000,00 - 50.000,00
        case "Apple", "Microsoft", "Tesla":
            // Stock prices (medium values)
            price = Double((rng % 20_000) + 10_000) / 100.0 // 100.00 - 300.00
        case "BMW":
            // BMW stock price
            price = Double((rng % 5_000) + 5_000) / 100.0 // 50.00 - 100.00
        case "Gold", "Silber":
            // Commodity prices
            price = Double((rng % 10_000) + 10_000) / 100.0 // 100.00 - 200.00
        case "USD/JPY", "EUR/USD", "GBP/USD":
            // Currency prices
            price = Double((rng % 5_000) + 10_000) / 100.0 // 100.00 - 150.00
        default:
            price = 150.00
        }

        // Generate percentage change
        let changePercent = Double((rng / 7) % 500) / 100.0 // 0.00 - 5.00
        let isPositive = (rng % 2) == 0
        let changeStr = String(format: "%@%.2f", isPositive ? "+ " : "- ", changePercent).replacingOccurrences(of: ".", with: ",")

        // Format price with German locale
        let priceStr = NumberFormatter.localizedDecimalFormatter.string(for: price) ?? "0,00"

        // Static time and market for now
        let timeStr = "15:30"
        let marketStr = "Xetra"

        return SecuritiesSearchViewModel.MarketData(price: priceStr, change: changeStr, time: timeStr, market: marketStr)
    }

    // MARK: - Private Methods

    private func generateStockResults(for filters: SearchFilters) -> [SearchResult] {
        // Generate stock results based on basiswert selection
        // Format: (symbol, name, wkn, isin)
        let allStocks = [
            ("Apple", "Apple Inc.", "865985", "US0378331005"),
            ("BMW", "BMW AG", "519000", "DE0005190003"),
            // ("DAX", "DAX Index", "846900", "DE0008469008"),
            ("Tesla", "Tesla Inc.", "881160", "US88160R1014"),
            ("Microsoft", "Microsoft Corp.", "594918", "US5949181045"),
            ("Google", "Alphabet Inc.", "02079K", "US02079K3059")
        ]

        // Filter stocks based on basiswert if specified
        var stocks: [(String, String, String, String)]
        if !filters.underlyingAsset.isEmpty {
            stocks = allStocks.filter { $0.0 == filters.underlyingAsset || $0.1.contains(filters.underlyingAsset) }
            // If no exact match, return all stocks (fallback behavior)
            if stocks.isEmpty {
                stocks = allStocks
            }
        } else {
            stocks = allStocks
        }

        return stocks.map { (symbol, _, wkn, isin) in
            // Generate deterministic prices based on symbol for consistency
            let seed = symbol.hash
            var random = seed

            let price = self.deterministicRandom(in: 50...500, seed: &random)

            return SearchResult(
                valuationDate: "31.12.2025",
                wkn: wkn,  // Use the correct WKN
                strike: String(format: "%.2f", price),
                askPrice: String(format: "%.2f", price),
                direction: nil, // Stocks don't have Call/Put direction
                underlyingType: "Aktie",
                isin: isin,
                underlyingAsset: symbol  // Use the symbol (underlying asset name) directly
            )
        }
    }

    func generateOptionsResults(for filters: SearchFilters) -> [SearchResult] {
        // CRITICAL: Generate options results based on ALL user filter selections
        // ALL filters MUST be respected - this is the core functionality
        // that was previously broken and must not be changed without thorough testing

        // CRITICAL: Direction filter - must match user selection
        let optionDirection = filters.direction == .call ? "Call" : "Put"

        // CRITICAL: Basiswert filter - must match user selection, fallback to DAX only if empty
        // This ensures the filter works correctly and prevents showing wrong underlying assets
        let underlyingAsset = filters.underlyingAsset.isEmpty ? "DAX" : filters.underlyingAsset

        // CRITICAL: Category filter - must match user selection
        let category = filters.category.isEmpty ? "Optionsschein" : filters.category

        print("🔍 DEBUG: MockDataGenerator.generateOptionsResults()")
        print("🔍 DEBUG: filters.direction = \(filters.direction)")
        print("🔍 DEBUG: filters.direction.rawValue = \(filters.direction.rawValue)")
        print("🔍 DEBUG: filters.underlyingAsset = '\(filters.underlyingAsset)'")
        print("🔍 DEBUG: optionDirection = \(optionDirection)")
        print("🔍 DEBUG: underlyingAsset = '\(underlyingAsset)'")

        // Map issuer names to 2-letter codes for WKN generation
        let issuerCodeMap: [String: String] = [
            "Société Générale": "SG",
            "Deutsche Bank": "DB",
            "Volksbank": "VT",
            "DZ Bank": "DZ",
            "BNP Paribas": "BN",
            "Citigroup": "CI",
            "Goldman Sachs": "GS",
            "HSBC": "HS",
            "J.P. Morgan": "JP",
            "Morgan Stanley": "MS",
            "UBS": "UB",
            "Vontobel": "VO"
        ]

        // Use selected issuer or default to random selection
        let availableCodes = ["SG", "DB", "VT", "DZ", "BN", "CI", "GS", "HS", "JP", "MS", "UB", "VO"]
        let selectedIssuer = filters.issuer.flatMap { issuerCodeMap[$0] } ?? availableCodes.randomElement() ?? "SG"

        var results: [SearchResult] = []

        // Determine number of results to generate based on issuer
        let resultCount: Int
        if selectedIssuer == "VO" || selectedIssuer == "DZ" {
            resultCount = 8  // Vontobel and DZ Bank get 8 hits for better testing
        } else {
            resultCount = 6  // Other issuers get 6 hits
        }

        // Generate different options for the selected criteria
        for index in 1...resultCount {
            let wkn = self.generateWKN(emittent: selectedIssuer, index: index)
            let isin = "DE000\(wkn)"

            // Generate realistic prices based on underlying asset
            // Use MarketPriceService to ensure consistency with displayed market price
            let basePrice = MarketPriceService.getMarketPrice(for: underlyingAsset)

            // Generate different strike prices for sorting with proper formatting
            let strike = self.generateStrikePrice(
                for: underlyingAsset,
                basePrice: basePrice,
                index: index,
                strikePriceGap: filters.strikePriceGap
            )

            // Generate briefkurs based on strike price gap relationship
            let briefkurs = self.generateBriefkurs(for: underlyingAsset, basePrice: basePrice, strike: strike, index: index)

            // Generate different valuation dates for sorting (spread across 2025-2026)
            let valuationDate = self.generateValuationDate(for: index)

            print("🔍 DEBUG: MockDataGenerator - Creating SearchResult with underlyingAsset: '\(underlyingAsset)'")

            // CRITICAL: Validate that we're using the correct filter values
            assert(!underlyingAsset.isEmpty, "Underlying asset should not be empty - this would break the basiswert filter")
            assert(underlyingAsset == filters.underlyingAsset || (filters.underlyingAsset.isEmpty && underlyingAsset == "DAX"),
                   "Underlying asset should match the selected basiswert or be DAX fallback")
            assert(!optionDirection.isEmpty, "Option direction should not be empty - this would break the direction filter")
            assert(optionDirection == "Call" || optionDirection == "Put",
                   "Option direction should be Call or Put - this would break the direction filter")
            assert(!category.isEmpty, "Category should not be empty - this would break the category filter")

            // Set subscription ratio based on category
            // Warrants typically have 0.01 or 0.1 subscription ratio
            let subscriptionRatio: Double
            if category.lowercased() == "warrant" || category.lowercased().contains("warrant") {
                // Use 0.01 for most warrants, sometimes 0.1 (based on index for variation)
                subscriptionRatio = (index % 3 == 0) ? 0.1 : 0.01
            } else {
                // Default to 1.0 for other securities
                subscriptionRatio = 1.0
            }

            let searchResult = SearchResult(
                valuationDate: valuationDate,
                wkn: wkn,
                strike: strike,
                askPrice: briefkurs,
                direction: optionDirection,        // CRITICAL: Use filtered direction
                category: category,                // CRITICAL: Use filtered category
                underlyingType: "Index",
                isin: isin,
                underlyingAsset: underlyingAsset,  // CRITICAL: Use filtered underlying asset
                subscriptionRatio: subscriptionRatio
            )

            print("🔍 DEBUG: Created SearchResult - WKN: \(searchResult.wkn)")
            print("🔍 DEBUG: Created SearchResult - direction: \(searchResult.direction ?? "nil")")
            print("🔍 DEBUG: Created SearchResult - underlyingAsset: \(searchResult.underlyingAsset ?? "nil")")
            results.append(searchResult)
        }

        return results
    }

    private func generateWKN(emittent: String, index: Int) -> String {
        // Use deterministic generation based on emittent and index for consistency
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let seed = "\(emittent)\(index)".hash
        var random = seed
        let randomSuffix = String((0..<4).map { _ in
            random = random &* 1_103_515_245 &+ 12_345  // Linear congruential generator
            return letters[letters.index(letters.startIndex, offsetBy: abs(random) % letters.count)]
        })
        return "\(emittent)\(index)\(randomSuffix)"
    }

    private func deterministicRandom(in range: ClosedRange<Double>, seed: inout Int) -> Double {
        seed = seed &* 1_103_515_245 &+ 12_345
        let normalized = Double(abs(seed) % 1_000) / 1_000.0
        return range.lowerBound + (range.upperBound - range.lowerBound) * normalized
    }

    private func generateStrikePrice(for underlyingAsset: String, basePrice: Double, index: Int, strikePriceGap: String?) -> String {
        // For index securities, use 50-point steps (fixed by issuer)
        if underlyingAsset.contains("DAX") || underlyingAsset.contains("Index") {
            // Generate strike prices in exact 50-point increments around base price
            // Strike prices are fixed values set by the issuer
            let baseStrike = Int(basePrice / 50) * 50  // Round to nearest 50-point increment

            // Generate 8 different strike prices in 50-point steps
            // Range: 3 strikes below base, base strike, 4 strikes above base
            let strikeValue = baseStrike + (50 * (index - 4))  // index 1-8, centered around base

            return String(format: "%.0f", Double(strikeValue))
        } else {
            // For stock securities, generate strike prices based on Strike Price Gap filter
            let strikeValue: Double

            if let gap = strikePriceGap {
                switch gap {
                case "At the Money":
                    // At the Money: ±1% of current price (approximately ±2 for Apple at 197.83)
                    let tolerance = basePrice * 0.01  // 1% tolerance
                    let minStrike = basePrice - tolerance
                    let maxStrike = basePrice + tolerance

                    // Generate strikes within the ±1% range
                    let range = maxStrike - minStrike
                    let step = range / 7.0  // 8 strikes total (index 1-8)
                    strikeValue = minStrike + (step * Double(index - 1))

                case "Out of the Money":
                    // Out of the Money: 5-15% below current price for calls, 5-15% above for puts
                    let tolerance = basePrice * 0.10  // 10% tolerance
                    let minStrike = basePrice - tolerance
                    let maxStrike = basePrice - (basePrice * 0.05)  // 5% below current price

                    let range = maxStrike - minStrike
                    let step = range / 7.0
                    strikeValue = minStrike + (step * Double(index - 1))

                case "In the Money":
                    // In the Money: 5-15% above current price for calls, 5-15% below for puts
                    let tolerance = basePrice * 0.10  // 10% tolerance
                    let minStrike = basePrice + (basePrice * 0.05)  // 5% above current price
                    let maxStrike = basePrice + tolerance

                    let range = maxStrike - minStrike
                    let step = range / 7.0
                    strikeValue = minStrike + (step * Double(index - 1))

                default:
                    // Default: wide range around current price
                    let minStrike = basePrice * 0.8
                    let maxStrike = basePrice * 1.2
                    let range = maxStrike - minStrike
                    let step = range / 7.0
                    strikeValue = minStrike + (step * Double(index - 1))
                }
            } else {
                // No filter specified: wide range around current price
                let minStrike = basePrice * 0.8
                let maxStrike = basePrice * 1.2
                let range = maxStrike - minStrike
                let step = range / 7.0
                strikeValue = minStrike + (step * Double(index - 1))
            }

            // Format with 2 decimal places for stock securities
            return String(format: "%.2f", strikeValue)
        }
    }

    private func generateBriefkurs(for underlyingAsset: String, basePrice: Double, strike: String, index: Int) -> String {
        // Parse strike price
        let strikePrice = Double(strike) ?? basePrice

        let briefkursValue: Double
        if underlyingAsset.contains("DAX") || underlyingAsset.contains("Index") {
            // For index securities (warrants), use proper financial calculation
            briefkursValue = self.calculateWarrantPrice(
                underlyingPrice: basePrice,
                strikePrice: strikePrice,
                conversionRatio: 0.01, // DAX warrants typically use 0.01
                index: index
            )
        } else {
            // For stock securities (warrants), use proper financial calculation with different conversion ratio
            briefkursValue = self.calculateWarrantPrice(
                underlyingPrice: basePrice,
                strikePrice: strikePrice,
                conversionRatio: 0.1, // Stock warrants typically use 0.1 (like BMW example)
                index: index
            )
        }

        return String(format: "%.2f", briefkursValue)
    }

    private func calculateWarrantPrice(underlyingPrice: Double, strikePrice: Double, conversionRatio: Double, index: Int) -> Double {
        // Step 1: Calculate Strike Price Gap
        let strikePriceGap = underlyingPrice - strikePrice

        // Step 2: Calculate Intrinsic Value
        // For call warrants: Intrinsic = max(0, (Underlying - Strike) × Conversion Ratio)
        let intrinsicValue = max(0, strikePriceGap * conversionRatio)

        // Step 3: Calculate Time Value (varies based on moneyness and time to expiry)
        let timeValue = self.calculateTimeValue(
            underlyingPrice: underlyingPrice,
            strikePrice: strikePrice,
            intrinsicValue: intrinsicValue,
            conversionRatio: conversionRatio,
            index: index
        )

        // Step 4: Warrant Price = Intrinsic Value + Time Value
        let warrantPrice = intrinsicValue + timeValue

        // Ensure minimum price of 0.01 (practical minimum for warrants)
        return max(0.01, warrantPrice)
    }

    private func calculateTimeValue(
        underlyingPrice: Double,
        strikePrice: Double,
        intrinsicValue: Double,
        conversionRatio: Double,
        index: Int
    ) -> Double {
        // Calculate moneyness (how far in/out of the money)
        let moneyness = (underlyingPrice - strikePrice) / underlyingPrice

        // Base time value varies by moneyness and security type
        let baseTimeValue: Double

        // Adjust time value based on conversion ratio (index vs stock warrants)
        let timeValueMultiplier = conversionRatio == 0.01 ? 1.0 : 0.1 // Index warrants have higher absolute time values

        if abs(moneyness) < 0.02 {
            // At the Money: higher time value
            if conversionRatio == 0.01 {
                // Index warrants: 2-4 points
                baseTimeValue = (2.0 + Double(index % 3) * 0.5) * timeValueMultiplier
            } else {
                // Stock warrants: 0.2-0.4 points (like BMW example: 0.4€)
                baseTimeValue = (0.2 + Double(index % 3) * 0.1) * timeValueMultiplier
            }
        } else if moneyness > 0 {
            // In the Money: moderate time value
            if conversionRatio == 0.01 {
                // Index warrants: 1-3 points
                baseTimeValue = (1.0 + Double(index % 3) * 0.5) * timeValueMultiplier
            } else {
                // Stock warrants: 0.1-0.3 points
                baseTimeValue = (0.1 + Double(index % 3) * 0.1) * timeValueMultiplier
            }
        } else {
            // Out of the Money: lower time value
            if conversionRatio == 0.01 {
                // Index warrants: 0.5-2 points
                baseTimeValue = (0.5 + Double(index % 3) * 0.3) * timeValueMultiplier
            } else {
                // Stock warrants: 0.05-0.15 points
                baseTimeValue = (0.05 + Double(index % 3) * 0.05) * timeValueMultiplier
            }
        }

        // Add some variation based on index for realistic spread
        let variation = Double(index % 5) * 0.01 * timeValueMultiplier

        return baseTimeValue + variation
    }

    private func generateValuationDate(for index: Int) -> String {
        // Generate different valuation dates spread across 2025-2026
        // This creates a mix of dates to test sorting functionality
        let dates = [
            "15.03.2025",  // Early 2025
            "30.06.2025",  // Mid 2025
            "15.09.2025",  // Late 2025
            "31.12.2025",  // End 2025
            "15.03.2026",  // Early 2026
            "30.06.2026",  // Mid 2026
            "15.09.2026",  // Late 2026
            "31.12.2026"   // End 2026
        ]

        // Use index to select date (with some variation for testing)
        let dateIndex = (index - 1) % dates.count
        return dates[dateIndex]
    }
}
