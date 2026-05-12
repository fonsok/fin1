import Foundation

// MARK: - Optimized Data Loader
final class OptimizedDataLoader: @unchecked Sendable {
    static let shared = OptimizedDataLoader()

    private var cache: [String: Any] = [:]
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    private var cacheTimestamps: [String: Date] = [:]

    private init() {}

    func loadData<T: Codable>(
        for key: String,
        loadFunction: @escaping () async throws -> T
    ) async throws -> T {
        // Check cache first
        if let cachedData = cache[key] as? T,
           let timestamp = cacheTimestamps[key],
           Date().timeIntervalSince(timestamp) < cacheExpiration {
            return cachedData
        }

        // Load fresh data
        let data = try await loadFunction()

        // Cache the data
        cache[key] = data
        cacheTimestamps[key] = Date()

        return data
    }

    func clearCache(for key: String? = nil) {
        if let key = key {
            cache.removeValue(forKey: key)
            cacheTimestamps.removeValue(forKey: key)
        } else {
            cache.removeAll()
            cacheTimestamps.removeAll()
        }
    }
}
