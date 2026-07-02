import Foundation

// MARK: - Trade Number Service Protocol

/// Protocol for managing sequential trade numbering system.
/// Trade numbers reset annually per trader (Europe/Berlin calendar year).
/// Parse Server is SSOT — `generateNextTradeNumber` is a local cache hint only; upsert assigns the authoritative number.
protocol TradeNumberServiceProtocol: ServiceLifecycle {
    /// Generates the next sequential trade number for a specific trader in the current calendar year.
    func generateNextTradeNumber(for traderId: String) -> Int

    @available(*, deprecated, message: "Use generateNextTradeNumber(for:) for per-trader numbering")
    func generateNextTradeNumber() -> Int

    func getCurrentTradeNumber(for traderId: String) -> Int

    func getCurrentTradeNumber() -> Int

    func formatTradeNumber(_ number: Int, year: Int?) -> String

    func isValidTradeNumber(_ number: Int) -> Bool

    func synchronizeTradeNumbers(from trades: [Trade])
}

// MARK: - Trade Number Service Implementation

final class TradeNumberService: TradeNumberServiceProtocol, @unchecked Sendable {

    private var traderTradeNumbers: [String: Int] = [:]
    private var globalTradeNumber: Int = 0
    private let userDefaults = UserDefaults.standard
    private let tradeNumberKeyPrefix = "FIN1_TradeNumber_"
    private let legacyTradeNumberKey = "FIN1_CurrentTradeNumber"
    private let queue = DispatchQueue(label: "com.fin.app.tradenumber", attributes: .concurrent)

    func start() async {
        self.loadLegacyTradeNumber()
    }

    func stop() async {}

    func reset() async {
        self.queue.sync {
            self.traderTradeNumbers.removeAll()
            self.globalTradeNumber = 0
        }
    }

    func generateNextTradeNumber(for traderId: String) -> Int {
        return self.queue.sync {
            let year = TradeNumberFormatting.calendarYear()
            let storageKey = self.traderStorageKey(traderId: traderId, year: year)

            if self.traderTradeNumbers[storageKey] == nil {
                self.traderTradeNumbers[storageKey] = self.userDefaults.integer(forKey: self.tradeNumberKey(traderId: traderId, year: year))
            }

            let currentNumber = (self.traderTradeNumbers[storageKey] ?? 0) + 1
            self.traderTradeNumbers[storageKey] = currentNumber
            self.saveTradeNumber(currentNumber, traderId: traderId, year: year)

            print(
                "🔢 TradeNumberService: Generated trade #\(TradeNumberFormatting.display(number: currentNumber, year: year)) for trader \(traderId)"
            )
            return currentNumber
        }
    }

    func generateNextTradeNumber() -> Int {
        return self.queue.sync {
            self.globalTradeNumber += 1
            self.userDefaults.set(self.globalTradeNumber, forKey: self.legacyTradeNumberKey)
            return self.globalTradeNumber
        }
    }

    func getCurrentTradeNumber(for traderId: String) -> Int {
        return self.queue.sync {
            let year = TradeNumberFormatting.calendarYear()
            let storageKey = self.traderStorageKey(traderId: traderId, year: year)
            if let number = traderTradeNumbers[storageKey] {
                return number
            }
            return self.userDefaults.integer(forKey: self.tradeNumberKey(traderId: traderId, year: year))
        }
    }

    func getCurrentTradeNumber() -> Int {
        return self.queue.sync {
            self.globalTradeNumber
        }
    }

    func synchronizeTradeNumbers(from trades: [Trade]) {
        self.queue.async(flags: .barrier) {
            let currentYear = TradeNumberFormatting.calendarYear()
            let tradesByTrader = Dictionary(grouping: trades) { $0.traderId }

            for (traderId, traderTrades) in tradesByTrader {
                let currentYearTrades = traderTrades.filter {
                    $0.resolvedTradeNumberYear == currentYear
                }
                let maxTradeNumber = currentYearTrades.map(\.tradeNumber).max() ?? 0
                let storageKey = self.traderStorageKey(traderId: traderId, year: currentYear)
                let currentStored = self.userDefaults.integer(forKey: self.tradeNumberKey(traderId: traderId, year: currentYear))

                if maxTradeNumber > currentStored {
                    self.traderTradeNumbers[storageKey] = maxTradeNumber
                    self.saveTradeNumber(maxTradeNumber, traderId: traderId, year: currentYear)
                    print(
                        "🔄 TradeNumberService: Synchronized \(traderId) to \(TradeNumberFormatting.display(number: maxTradeNumber, year: currentYear))"
                    )
                }
            }
        }
    }

    func formatTradeNumber(_ number: Int, year: Int? = nil) -> String {
        let resolvedYear = year ?? TradeNumberFormatting.calendarYear()
        return TradeNumberFormatting.display(number: number, year: resolvedYear)
    }

    func isValidTradeNumber(_ number: Int) -> Bool {
        number > 0
    }

    private func traderStorageKey(traderId: String, year: Int) -> String {
        "\(year)|\(traderId)"
    }

    private func tradeNumberKey(traderId: String, year: Int) -> String {
        let sanitizedId = traderId
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "@", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        return "\(self.tradeNumberKeyPrefix)\(year)_user_\(sanitizedId)"
    }

    private func saveTradeNumber(_ number: Int, traderId: String, year: Int) {
        let key = self.tradeNumberKey(traderId: traderId, year: year)
        self.userDefaults.set(number, forKey: key)
    }

    private func loadLegacyTradeNumber() {
        self.queue.sync {
            self.globalTradeNumber = self.userDefaults.integer(forKey: self.legacyTradeNumberKey)
        }
    }
}

extension TradeNumberService {
    func formattedCurrentTradeNumber(for traderId: String) -> String {
        let year = TradeNumberFormatting.calendarYear()
        return self.formatTradeNumber(self.getCurrentTradeNumber(for: traderId), year: year)
    }

    func formattedNextTradeNumber(for traderId: String) -> String {
        let year = TradeNumberFormatting.calendarYear()
        return self.formatTradeNumber(self.generateNextTradeNumber(for: traderId), year: year)
    }

    @available(*, deprecated, message: "Use formattedCurrentTradeNumber(for:) for per-trader numbering")
    var formattedCurrentTradeNumber: String {
        self.formatTradeNumber(self.getCurrentTradeNumber(), year: TradeNumberFormatting.calendarYear())
    }

    @available(*, deprecated, message: "Use formattedNextTradeNumber(for:) for per-trader numbering")
    var formattedNextTradeNumber: String {
        self.formatTradeNumber(self.generateNextTradeNumber(), year: TradeNumberFormatting.calendarYear())
    }
}
