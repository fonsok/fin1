import Foundation
import Combine

// MARK: - Offline Operation Queue

/// Manages offline operations that need to be synchronized when network becomes available
@MainActor
final class OfflineOperationQueue: ObservableObject {
    static let shared = OfflineOperationQueue()

    @Published private(set) var pendingOperations: [QueuedOperation] = []
    @Published private(set) var failedOperations: [QueuedOperation] = []
    @Published private(set) var isProcessing = false

    enum OperationType: String, Codable, Sendable {
        case create
        case update
        case delete
        case callFunction
    }

    struct QueuedOperation: Codable, Identifiable, Sendable {
        let id: String
        let type: OperationType
        let className: String?
        let objectId: String?
        let functionName: String?
        let payload: Data
        let createdAt: Date
        var retryCount: Int
        let userId: String?

        init(
            id: String = UUID().uuidString,
            type: OperationType,
            className: String? = nil,
            objectId: String? = nil,
            functionName: String? = nil,
            payload: Data,
            createdAt: Date = Date(),
            retryCount: Int = 0,
            userId: String? = nil
        ) {
            self.id = id
            self.type = type
            self.className = className
            self.objectId = objectId
            self.functionName = functionName
            self.payload = payload
            self.createdAt = createdAt
            self.retryCount = retryCount
            self.userId = userId
        }
    }

    private let persistenceKey = "offline_operations_queue"
    private let maxRetries = 5
    private var parseAPIClient: (any ParseAPIClientProtocol)?
    private var parseServerConfig: ParseServerConfig?

    private init() {
        loadQueue()
    }

    /// Configure the Parse API client for processing operations
    func configure(parseAPIClient: any ParseAPIClientProtocol) {
        self.parseAPIClient = parseAPIClient
        self.parseServerConfig = ParseServerConfig(from: parseAPIClient)
    }

    // MARK: - Queue Management

    func enqueue(_ operation: QueuedOperation) {
        pendingOperations.append(operation)
        persistQueue()

        #if DEBUG
        print("📦 OfflineOperationQueue: Enqueued operation \(operation.type.rawValue) for \(operation.className ?? operation.functionName ?? "unknown")")
        #endif
    }

    func removeOperation(_ operationId: String) {
        pendingOperations.removeAll { $0.id == operationId }
        persistQueue()
    }

    func moveToFailed(_ operation: QueuedOperation) {
        pendingOperations.removeAll { $0.id == operation.id }
        failedOperations.append(operation)
        persistQueue()
    }

    func clearFailed() {
        failedOperations.removeAll()
        persistQueue()
    }

    // MARK: - Queue Processing

    func processQueue() async {
        guard !isProcessing else {
            #if DEBUG
            print("⚠️ OfflineOperationQueue: Already processing queue")
            #endif
            return
        }

        guard NetworkMonitor.shared.isConnected else {
            #if DEBUG
            print("⚠️ OfflineOperationQueue: No network connection, skipping queue processing")
            #endif
            return
        }

        guard let apiClient = parseAPIClient else {
            #if DEBUG
            print("⚠️ OfflineOperationQueue: No ParseAPIClient configured")
            #endif
            return
        }
        guard let config = parseServerConfig else {
            #if DEBUG
            print("⚠️ OfflineOperationQueue: Missing Parse server config, skipping queue processing")
            #endif
            return
        }

        isProcessing = true

        let operations = pendingOperations
        #if DEBUG
        print("🔄 OfflineOperationQueue: Processing \(operations.count) operations")
        #endif

        // Snapshot the current session token for the processing run.
        // This avoids moving a non-Sendable API client across concurrency boundaries.
        let sessionToken: String? = {
            if let concrete = apiClient as? ParseAPIClient {
                return concrete.sessionToken
            }
            return nil
        }()

        for operation in operations {
            do {
                // Execute off-main without capturing the non-Sendable apiClient.
                try await OfflineOperationQueue.executeOperationOffMain(
                    operation,
                    baseURL: config.baseURL,
                    applicationId: config.applicationId,
                    sessionToken: sessionToken
                )
                removeOperation(operation.id)
                #if DEBUG
                print("✅ OfflineOperationQueue: Successfully processed operation \(operation.id)")
                #endif
            } catch {
                var updatedOperation = operation
                updatedOperation.retryCount += 1

                if updatedOperation.retryCount >= maxRetries {
                    moveToFailed(updatedOperation)
                    #if DEBUG
                    print("❌ OfflineOperationQueue: Operation \(operation.id) failed after \(maxRetries) retries, moved to failed")
                    #endif
                } else {
                    // Update retry count
                    if let index = pendingOperations.firstIndex(where: { $0.id == operation.id }) {
                        pendingOperations[index] = updatedOperation
                        persistQueue()
                    }
                    #if DEBUG
                    print("⚠️ OfflineOperationQueue: Operation \(operation.id) failed, retry count: \(updatedOperation.retryCount)/\(maxRetries)")
                    #endif
                }
            }
        }

        isProcessing = false
    }

    // MARK: - Operation Execution
    fileprivate static func executeOperationOffMain(
        _ operation: QueuedOperation,
        baseURL: String,
        applicationId: String,
        sessionToken: String?
    ) async throws {
        let client = ParseAPIClient(
            baseURL: baseURL,
            applicationId: applicationId,
            sessionTokenProvider: sessionToken != nil ? { sessionToken } : nil,
            offlineQueue: nil
        )
        try await Self.executeOperation(operation, apiClient: client)
    }

    private static func executeOperation(_ operation: QueuedOperation, apiClient: any ParseAPIClientProtocol) async throws {
        switch operation.type {
        case .create:
            guard let className = operation.className else {
                throw OfflineOperationError.missingClassName
            }
            let decoder = JSONDecoder()
            let payload = try decoder.decode([String: AnyCodable].self, from: operation.payload)
            _ = try await apiClient.createObject(className: className, object: payload)

        case .update:
            guard let className = operation.className,
                  let objectId = operation.objectId else {
                throw OfflineOperationError.missingParameters
            }
            let decoder = JSONDecoder()
            let payload = try decoder.decode([String: AnyCodable].self, from: operation.payload)
            _ = try await apiClient.updateObject(className: className, objectId: objectId, object: payload)

        case .delete:
            guard let className = operation.className,
                  let objectId = operation.objectId else {
                throw OfflineOperationError.missingParameters
            }
            try await apiClient.deleteObject(className: className, objectId: objectId)

        case .callFunction:
            guard let functionName = operation.functionName else {
                throw OfflineOperationError.missingFunctionName
            }
            let decoder = JSONDecoder()
            let parameters = try decoder.decode([String: AnyCodable].self, from: operation.payload)
            let _: AnyCodable = try await apiClient.callFunction(functionName, parameters: parameters)
        }
    }

    // MARK: - Persistence

    private func persistQueue() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(pendingOperations) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }

        if let failedData = try? encoder.encode(failedOperations) {
            UserDefaults.standard.set(failedData, forKey: "\(persistenceKey)_failed")
        }
    }

    private func loadQueue() {
        if let data = UserDefaults.standard.data(forKey: persistenceKey),
           let operations = try? JSONDecoder().decode([QueuedOperation].self, from: data) {
            pendingOperations = operations
        }

        if let failedData = UserDefaults.standard.data(forKey: "\(persistenceKey)_failed"),
           let failed = try? JSONDecoder().decode([QueuedOperation].self, from: failedData) {
            failedOperations = failed
        }
    }
}

// MARK: - Supporting Types

enum OfflineOperationError: Error {
    case missingClassName
    case missingParameters
    case missingFunctionName

    var localizedDescription: String {
        switch self {
        case .missingClassName:
            return "Missing class name for operation"
        case .missingParameters:
            return "Missing required parameters for operation"
        case .missingFunctionName:
            return "Missing function name for operation"
        }
    }
}

// Helper type for encoding/decoding Any values
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }

    var stringValue: String? {
        return value as? String
    }
}

private struct ParseServerConfig: Sendable {
    let baseURL: String
    let applicationId: String

    init?(from apiClient: any ParseAPIClientProtocol) {
        guard let concrete = apiClient as? ParseAPIClient else { return nil }
        self.baseURL = concrete.baseURL
        self.applicationId = concrete.applicationId
    }
}
