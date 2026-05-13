import Foundation
import OSLog

// MARK: - Network Logger

/// Logs network requests and responses for debugging and monitoring
final class NetworkLogger: @unchecked Sendable {
    static let shared = NetworkLogger()

    private let logger = Logger(subsystem: "com.fin1.app", category: "Network")
    private let maxLogEntries = 1_000
    private var logEntries: [LogEntry] = []
    private let logQueue = DispatchQueue(label: "NetworkLogger", qos: .utility)

    struct LogEntry: Codable, Identifiable {
        let id: String
        let timestamp: Date
        let endpoint: String
        let method: String
        let statusCode: Int?
        let duration: TimeInterval
        let requestSize: Int?
        let responseSize: Int?
        let error: String?
        let retryCount: Int

        init(
            id: String = UUID().uuidString,
            timestamp: Date = Date(),
            endpoint: String,
            method: String,
            statusCode: Int? = nil,
            duration: TimeInterval,
            requestSize: Int? = nil,
            responseSize: Int? = nil,
            error: String? = nil,
            retryCount: Int = 0
        ) {
            self.id = id
            self.timestamp = timestamp
            self.endpoint = endpoint
            self.method = method
            self.statusCode = statusCode
            self.duration = duration
            self.requestSize = requestSize
            self.responseSize = responseSize
            self.error = error
            self.retryCount = retryCount
        }
    }

    private init() {
        self.loadPersistedLogs()
    }

    // MARK: - Logging

    func logRequest(
        endpoint: String,
        method: String,
        statusCode: Int?,
        duration: TimeInterval,
        requestSize: Int? = nil,
        responseSize: Int? = nil,
        error: Error? = nil,
        retryCount: Int = 0
    ) {
        let entry = LogEntry(
            endpoint: endpoint,
            method: method,
            statusCode: statusCode,
            duration: duration,
            requestSize: requestSize,
            responseSize: responseSize,
            error: error?.localizedDescription,
            retryCount: retryCount
        )

        self.logQueue.async { [weak self] in
            self?.addLogEntry(entry)
        }

        // Log to OSLog for debugging
        let statusEmoji = statusCode.map { $0 >= 200 && $0 < 300 ? "✅" : "❌" } ?? "⚠️"
        let durationStr = String(format: "%.3f", duration)
        let sizeStr = responseSize.map { "\($0) bytes" } ?? "unknown"

        self.logger.info("\(statusEmoji) [\(method)] \(endpoint) - \(statusCode?.description ?? "N/A") - \(durationStr)s - \(sizeStr)")

        if let error = error {
            self.logger.error("Error: \(error.localizedDescription)")
        }

        if retryCount > 0 {
            self.logger.info("Retry count: \(retryCount)")
        }
    }

    // MARK: - Log Management

    private func addLogEntry(_ entry: LogEntry) {
        self.logEntries.append(entry)

        // Keep only recent entries
        if self.logEntries.count > self.maxLogEntries {
            self.logEntries.removeFirst(self.logEntries.count - self.maxLogEntries)
        }

        self.persistLogs()
    }

    func getRecentLogs(limit: Int = 100) -> [LogEntry] {
        return self.logQueue.sync {
            Array(self.logEntries.suffix(limit))
        }
    }

    func getLogsForEndpoint(_ endpoint: String, limit: Int = 50) -> [LogEntry] {
        return self.logQueue.sync {
            self.logEntries
                .filter { $0.endpoint.contains(endpoint) }
                .suffix(limit)
                .reversed()
        }
    }

    func getErrorLogs(limit: Int = 50) -> [LogEntry] {
        return self.logQueue.sync {
            self.logEntries
                .filter { $0.error != nil || ($0.statusCode != nil && $0.statusCode! >= 400) }
                .suffix(limit)
                .reversed()
        }
    }

    func clearLogs() {
        self.logQueue.async { [weak self] in
            self?.logEntries.removeAll()
            self?.persistLogs()
        }
    }

    // MARK: - Statistics

    struct Statistics {
        let totalRequests: Int
        let successfulRequests: Int
        let failedRequests: Int
        let averageDuration: TimeInterval
        let totalDataTransferred: Int
        let errorRate: Double
    }

    func getStatistics() -> Statistics {
        return self.logQueue.sync {
            let total = self.logEntries.count
            let successful = self.logEntries.filter { $0.statusCode != nil && $0.statusCode! >= 200 && $0.statusCode! < 300 }.count
            let failed = self.logEntries.filter { $0.error != nil || ($0.statusCode != nil && $0.statusCode! >= 400) }.count
            let avgDuration = self.logEntries.isEmpty ? 0 : self.logEntries.map { $0.duration }.reduce(0, +) / Double(self.logEntries.count)
            let totalData = self.logEntries.compactMap { $0.responseSize }.reduce(0, +)
            let errorRate = total > 0 ? Double(failed) / Double(total) : 0.0

            return Statistics(
                totalRequests: total,
                successfulRequests: successful,
                failedRequests: failed,
                averageDuration: avgDuration,
                totalDataTransferred: totalData,
                errorRate: errorRate
            )
        }
    }

    // MARK: - Persistence

    private func persistLogs() {
        // Only persist error logs and recent logs to avoid storage bloat
        let logsToPersist = Array(logEntries.suffix(100))
        if let data = try? JSONEncoder().encode(logsToPersist) {
            UserDefaults.standard.set(data, forKey: "network_logs")
        }
    }

    private func loadPersistedLogs() {
        if let data = UserDefaults.standard.data(forKey: "network_logs"),
           let logs = try? JSONDecoder().decode([LogEntry].self, from: data) {
            self.logEntries = logs
        }
    }
}

// MARK: - Extensions

extension Int {
    var description: String {
        return String(self)
    }
}
