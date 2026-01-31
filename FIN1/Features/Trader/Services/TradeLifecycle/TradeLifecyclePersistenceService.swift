import Foundation

// MARK: - Trade Lifecycle Persistence Service

/// Handles persistence operations for TradeLifecycleService
/// Separated to reduce main service file size and improve maintainability
final class TradeLifecyclePersistenceService {
    private let fileManager: FileManager
    private let storageDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "com.fin.app.tradelifecycle.persistence", attributes: .concurrent)

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.storageDirectory = TradeLifecyclePersistenceService.makeStorageDirectory(using: fileManager)

        // Configure JSON encoder/decoder with proper date handling
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Loads persisted trades from disk, organized by trader ID
    func loadPersistedTrades(completion: @escaping ([Trade]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion([])
                return
            }

            var allTrades: [Trade] = []

            // Load all trade files from storage directory
            guard self.fileManager.fileExists(atPath: self.storageDirectory.path) else {
                print("📁 TradeLifecyclePersistenceManager: Storage directory doesn't exist yet - no persisted trades")
                completion([])
                return
            }

            do {
                let fileURLs = try self.fileManager.contentsOfDirectory(
                    at: self.storageDirectory,
                    includingPropertiesForKeys: nil
                ).filter { $0.pathExtension == "json" }

                for fileURL in fileURLs {
                    if let trades = self.loadTradesFromFile(at: fileURL) {
                        allTrades.append(contentsOf: trades)
                        print("📁 TradeLifecyclePersistenceManager: Loaded \(trades.count) trades from \(fileURL.lastPathComponent)")
                    }
                }

                print("✅ TradeLifecyclePersistenceManager: Loaded \(allTrades.count) total persisted trades")
                completion(allTrades)
            } catch {
                print("⚠️ TradeLifecyclePersistenceManager: Failed to load persisted trades - \(error)")
                completion([])
            }
        }
    }

    /// Loads trades from a specific file
    private func loadTradesFromFile(at url: URL) -> [Trade]? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        do {
            return try decoder.decode([Trade].self, from: data)
        } catch {
            print("⚠️ TradeLifecyclePersistenceManager: Failed to decode trades from \(url.lastPathComponent) - \(error)")
            return nil
        }
    }

    /// Persists all trades to disk, organized by trader ID
    func persistTrades(_ trades: [Trade]) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // Group trades by trader ID for per-trader file organization
            let tradesByTrader = Dictionary(grouping: trades) { $0.traderId }

            for (traderId, traderTrades) in tradesByTrader {
                let fileName = self.sanitizeTraderId(traderId) + ".json"
                let fileURL = self.storageDirectory.appendingPathComponent(fileName)

                do {
                    let data = try self.encoder.encode(traderTrades)
                    try data.write(to: fileURL, options: .atomic)
                    print("💾 TradeLifecyclePersistenceManager: Persisted \(traderTrades.count) trades for trader \(traderId)")
                } catch {
                    print("⚠️ TradeLifecyclePersistenceManager: Failed to persist trades for trader \(traderId) - \(error)")
                }
            }
        }
    }

    /// Clears all persisted trades from disk
    func clearPersistedTrades() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            do {
                let fileURLs = try self.fileManager.contentsOfDirectory(
                    at: self.storageDirectory,
                    includingPropertiesForKeys: nil
                ).filter { $0.pathExtension == "json" }

                for fileURL in fileURLs {
                    try? self.fileManager.removeItem(at: fileURL)
                }

                print("🗑️ TradeLifecyclePersistenceManager: Cleared all persisted trades")
            } catch {
                print("⚠️ TradeLifecyclePersistenceManager: Failed to clear persisted trades - \(error)")
            }
        }
    }

    /// Clears persisted trades for a specific trader (synchronous to ensure it completes)
    func clearPersistedTradesForTrader(_ traderId: String) {
        queue.sync(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let fileName = self.sanitizeTraderId(traderId) + ".json"
            let fileURL = self.storageDirectory.appendingPathComponent(fileName)

            do {
                if self.fileManager.fileExists(atPath: fileURL.path) {
                    try self.fileManager.removeItem(at: fileURL)
                    print("🗑️ TradeLifecyclePersistenceManager: Removed persisted trades file for trader \(traderId)")
                } else {
                    print("📁 TradeLifecyclePersistenceManager: No persisted trades file found for trader \(traderId)")
                }
            } catch {
                print("⚠️ TradeLifecyclePersistenceManager: Failed to remove persisted trades for trader \(traderId): \(error)")
            }
        }
    }

    /// Creates the storage directory if it doesn't exist
    private static func makeStorageDirectory(using fileManager: FileManager) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let tradesDirectory = baseDirectory.appendingPathComponent("Trades", isDirectory: true)

        if !fileManager.fileExists(atPath: tradesDirectory.path) {
            do {
                try fileManager.createDirectory(at: tradesDirectory, withIntermediateDirectories: true)
                print("📁 TradeLifecyclePersistenceManager: Created storage directory at \(tradesDirectory.path)")
            } catch {
                print("⚠️ TradeLifecyclePersistenceManager: Failed to create storage directory - \(error)")
            }
        }

        return tradesDirectory
    }

    /// Sanitizes trader ID for use as filename
    private func sanitizeTraderId(_ traderId: String) -> String {
        return traderId
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "@", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "/", with: "_")
    }
}

