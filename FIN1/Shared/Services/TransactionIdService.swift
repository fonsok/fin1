import CryptoKit
import Foundation

// MARK: - Transaction ID Service

/// Service for generating unique transaction identifiers following financial sector standards
/// Implements temporal ordering, system identification, and uniqueness guarantees
final class TransactionIdService: TransactionIdServiceProtocol {

    // MARK: - Properties

    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    private var dailyCounters: [String: [String: Int]] = [:]
    private let queue = DispatchQueue(label: "com.fin.app.transactionid", attributes: .concurrent)
    private var systemPrefix: String { LegalIdentity.documentPrefix }

    // MARK: - Initialization

    init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyyMMdd"
        self.dateFormatter.timeZone = TimeZone(identifier: "Europe/Berlin")

        self.timeFormatter = DateFormatter()
        self.timeFormatter.dateFormat = "HHmmss"
        self.timeFormatter.timeZone = TimeZone(identifier: "Europe/Berlin")
    }

    // MARK: - ServiceLifecycle

    func start() async {
        // Initialize daily counters for current date
        let today = self.dateFormatter.string(from: Date())
        self.dailyCounters[today] = [:]
    }

    func stop() async {
        // Clean up old counters (keep only last 7 days)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let cutoffString = self.dateFormatter.string(from: cutoffDate)

        self.dailyCounters = self.dailyCounters.filter { $0.key >= cutoffString }
    }

    func reset() async {
        self.dailyCounters.removeAll()
        await self.start()
    }

    // MARK: - Public Methods

    func generateOrderId() -> String {
        return self.generateId(prefix: "ORD")
    }

    func generateTradeId() -> String {
        return self.generateId(prefix: "TRD")
    }

    func generateInvoiceNumber() -> String {
        return self.generateId(prefix: "INV", includeTime: false)
    }

    func generateInvestorDocumentNumber() -> String {
        return self.generateId(prefix: "INVST", includeTime: false)
    }

    func generatePaymentId() -> String {
        return self.generateId(prefix: "PAY")
    }

    func generateCustomerId() -> String {
        let year = Calendar.current.component(.year, from: Date())
        let randomNumber = String(format: "%05d", Int.random(in: 1...99_999))
        return "\(self.systemPrefix)-\(year)-\(randomNumber)"
    }

    func validateId(_ id: String) -> Bool {
        // Validate format: <PREFIX>-<TYPE>-YYYYMMDD[-HHMMSS]-XXXXX
        let escapedPrefix = NSRegularExpression.escapedPattern(for: self.systemPrefix)
        let pattern = "^\(escapedPrefix)-[A-Z]{3,5}-\\d{8}(-\\d{6})?-\\d{5}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: id.utf16.count)
        return regex?.firstMatch(in: id, options: [], range: range) != nil
    }

    // MARK: - Private Methods

    private func generateId(prefix: String, includeTime: Bool = true) -> String {
        return self.queue.sync {
            let now = Date()
            let dateString = self.dateFormatter.string(from: now)
            let timeString = includeTime ? "-\(timeFormatter.string(from: now))" : ""
            let counter = self.getNextCounter(for: dateString, prefix: prefix)
            return "\(self.systemPrefix)-\(prefix)-\(dateString)\(timeString)-\(String(format: "%05d", counter))"
        }
    }

    private func getNextCounter(for date: String, prefix: String) -> Int {
        if self.dailyCounters[date] == nil {
            self.dailyCounters[date] = [:]
        }

        let currentCount = self.dailyCounters[date]?[prefix] ?? 0
        let nextCount = currentCount + 1
        self.dailyCounters[date]?[prefix] = nextCount
        return nextCount
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        return formatter
    }()
}
