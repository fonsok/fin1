import Foundation

// MARK: - Trade Number Service Protocol

/// Protocol for managing sequential trade numbering system
/// Trade numbers are now per-trader to ensure each trader has their own sequence
protocol TradeNumberServiceProtocol: ServiceLifecycle {
    /// Generates the next sequential trade number for a specific trader (001, 002, 003...)
    /// - Parameter traderId: The trader's unique identifier
    /// - Returns: Next trade number in sequence for this trader
    func generateNextTradeNumber(for traderId: String) -> Int

    /// Legacy method for backward compatibility - uses global counter
    /// - Returns: Next trade number in global sequence
    @available(*, deprecated, message: "Use generateNextTradeNumber(for:) for per-trader numbering")
    func generateNextTradeNumber() -> Int

    /// Gets the current highest trade number for a specific trader
    /// - Parameter traderId: The trader's unique identifier
    /// - Returns: Current highest trade number for this trader, or 0 if none exist
    func getCurrentTradeNumber(for traderId: String) -> Int

    /// Gets the current highest trade number (legacy global)
    /// - Returns: Current highest trade number, or 0 if none exist
    func getCurrentTradeNumber() -> Int

    /// Formats a trade number for display (e.g., 1 -> "001")
    /// - Parameter number: The trade number to format
    /// - Returns: Formatted trade number string
    func formatTradeNumber(_ number: Int) -> String

    /// Validates if a trade number is valid
    /// - Parameter number: The trade number to validate
    /// - Returns: True if the trade number is valid
    func isValidTradeNumber(_ number: Int) -> Bool

    /// Synchronizes trade numbers from existing trades
    /// This ensures the service knows the highest trade number for each trader
    /// - Parameter trades: Array of trades to synchronize from
    func synchronizeTradeNumbers(from trades: [Trade])
}

// MARK: - Trade Number Service Implementation

/// Service for managing sequential trade numbering system
/// Provides user-friendly trade numbers (001, 002, 003...) per trader while maintaining UUIDs for internal linking
final class TradeNumberService: TradeNumberServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private var traderTradeNumbers: [String: Int] = [:]  // Per-trader counters
    private var globalTradeNumber: Int = 0  // Legacy global counter for backward compatibility
    private let userDefaults = UserDefaults.standard
    private let tradeNumberKeyPrefix = "FIN1_TradeNumber_"  // Per-trader key prefix
    private let legacyTradeNumberKey = "FIN1_CurrentTradeNumber"  // Legacy global key
    private let queue = DispatchQueue(label: "com.fin.app.tradenumber", attributes: .concurrent)

    // MARK: - ServiceLifecycle

    func start() async {
        self.loadLegacyTradeNumber()
    }

    func stop() async {
        // Per-trader numbers are saved immediately on generation
    }

    func reset() async {
        // Note: reset() is async to match protocol, but operations are synchronous
        self.queue.sync {
            self.traderTradeNumbers.removeAll()
            self.globalTradeNumber = 0
            // Note: We don't clear UserDefaults here to preserve data between sessions
        }
    }

    // MARK: - Public Methods

    /// Generates the next trade number for a specific trader
    func generateNextTradeNumber(for traderId: String) -> Int {
        return self.queue.sync {
            // Load current number for this trader if not in memory
            if self.traderTradeNumbers[traderId] == nil {
                let key = self.tradeNumberKey(for: traderId)
                self.traderTradeNumbers[traderId] = self.userDefaults.integer(forKey: key)
            }

            // Increment and save
            let currentNumber = (traderTradeNumbers[traderId] ?? 0) + 1
            self.traderTradeNumbers[traderId] = currentNumber
            self.saveTradeNumber(currentNumber, for: traderId)

            print("🔢 TradeNumberService: Generated trade #\(currentNumber) for trader \(traderId)")
            return currentNumber
        }
    }

    /// Legacy global method - deprecated but kept for backward compatibility
    func generateNextTradeNumber() -> Int {
        return self.queue.sync {
            self.globalTradeNumber += 1
            self.userDefaults.set(self.globalTradeNumber, forKey: self.legacyTradeNumberKey)
            return self.globalTradeNumber
        }
    }

    /// Gets the current trade number for a specific trader
    func getCurrentTradeNumber(for traderId: String) -> Int {
        return self.queue.sync {
            if let number = traderTradeNumbers[traderId] {
                return number
            }
            let key = self.tradeNumberKey(for: traderId)
            return self.userDefaults.integer(forKey: key)
        }
    }

    func getCurrentTradeNumber() -> Int {
        return self.queue.sync {
            return self.globalTradeNumber
        }
    }

    /// Synchronizes trade numbers from existing trades
    /// This ensures the service knows the highest trade number for each trader
    /// - Parameter trades: Array of trades to synchronize from
    func synchronizeTradeNumbers(from trades: [Trade]) {
        self.queue.async(flags: .barrier) {
            // Group trades by trader ID
            let tradesByTrader = Dictionary(grouping: trades) { $0.traderId }

            // For each trader, find the highest trade number
            for (traderId, traderTrades) in tradesByTrader {
                let maxTradeNumber = traderTrades.map { $0.tradeNumber }.max() ?? 0

                // Update the counter if the loaded trades have a higher number
                let currentStored = self.userDefaults.integer(forKey: self.tradeNumberKey(for: traderId))
                if maxTradeNumber > currentStored {
                    self.traderTradeNumbers[traderId] = maxTradeNumber
                    self.saveTradeNumber(maxTradeNumber, for: traderId)
                    print("🔄 TradeNumberService: Synchronized trade number for trader \(traderId) to \(maxTradeNumber)")
                }
            }
        }
    }

    func formatTradeNumber(_ number: Int) -> String {
        return String(format: "%03d", number)
    }

    func isValidTradeNumber(_ number: Int) -> Bool {
        return number > 0 && number <= 999
    }

    // MARK: - Private Methods

    private func tradeNumberKey(for traderId: String) -> String {
        // Sanitize trader ID for use as UserDefaults key
        // Format: FIN1_TradeNumber_user_trader1_test_com
        let sanitizedId = traderId.replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "@", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        return "\(self.tradeNumberKeyPrefix)user_\(sanitizedId)"
    }

    private func saveTradeNumber(_ number: Int, for traderId: String) {
        let key = self.tradeNumberKey(for: traderId)
        self.userDefaults.set(number, forKey: key)
    }

    private func loadLegacyTradeNumber() {
        self.queue.sync {
            self.globalTradeNumber = self.userDefaults.integer(forKey: self.legacyTradeNumberKey)
        }
    }
}

// MARK: - Extensions

extension TradeNumberService {
    /// Convenience method to get formatted current trade number for a trader
    func formattedCurrentTradeNumber(for traderId: String) -> String {
        return self.formatTradeNumber(self.getCurrentTradeNumber(for: traderId))
    }

    /// Convenience method to get formatted next trade number for a trader
    func formattedNextTradeNumber(for traderId: String) -> String {
        return self.formatTradeNumber(self.generateNextTradeNumber(for: traderId))
    }

    /// Legacy convenience method - uses global counter
    @available(*, deprecated, message: "Use formattedCurrentTradeNumber(for:) for per-trader numbering")
    var formattedCurrentTradeNumber: String {
        return self.formatTradeNumber(self.getCurrentTradeNumber())
    }

    /// Legacy convenience method - uses global counter
    @available(*, deprecated, message: "Use formattedNextTradeNumber(for:) for per-trader numbering")
    var formattedNextTradeNumber: String {
        return self.formatTradeNumber(self.generateNextTradeNumber())
    }
}
