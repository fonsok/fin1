import Foundation

// MARK: - Conflict Resolution Service

/// Handles conflicts when multiple devices update the same object simultaneously
protocol ConflictResolutionServiceProtocol {
    /// Resolves a conflict between local and remote versions of an object
    /// - Parameters:
    ///   - local: The local version of the object
    ///   - remote: The remote version from the server
    ///   - localUpdatedAt: The timestamp when the local version was last updated
    ///   - remoteUpdatedAt: The timestamp when the remote version was last updated
    /// - Returns: The resolved version of the object
    /// - Throws: ConflictResolutionError if resolution fails
    func resolveConflict<T: Codable>(
        local: T,
        remote: T,
        localUpdatedAt: Date?,
        remoteUpdatedAt: Date?
    ) async throws -> T
}

// MARK: - Conflict Resolution Strategies

enum ConflictResolutionStrategy {
    case lastWriteWins
    case firstWriteWins
    case manualResolution
    case fieldLevelMerging
}

// MARK: - Conflict Resolution Service Implementation

final class ConflictResolutionService: ConflictResolutionServiceProtocol {
    private let strategy: ConflictResolutionStrategy

    init(strategy: ConflictResolutionStrategy = .lastWriteWins) {
        self.strategy = strategy
    }

    func resolveConflict<T: Codable>(
        local: T,
        remote: T,
        localUpdatedAt: Date?,
        remoteUpdatedAt: Date?
    ) async throws -> T {
        switch self.strategy {
        case .lastWriteWins:
            return try self.resolveLastWriteWins(
                local: local,
                remote: remote,
                localUpdatedAt: localUpdatedAt,
                remoteUpdatedAt: remoteUpdatedAt
            )

        case .firstWriteWins:
            return try self.resolveFirstWriteWins(
                local: local,
                remote: remote,
                localUpdatedAt: localUpdatedAt,
                remoteUpdatedAt: remoteUpdatedAt
            )

        case .fieldLevelMerging:
            return try self.resolveFieldLevelMerging(
                local: local,
                remote: remote,
                localUpdatedAt: localUpdatedAt,
                remoteUpdatedAt: remoteUpdatedAt
            )

        case .manualResolution:
            throw ConflictResolutionError.manualResolutionRequired(
                localDescription: String(describing: local),
                remoteDescription: String(describing: remote)
            )
        }
    }

    // MARK: - Resolution Strategies

    /// Last Write Wins: The most recent update takes precedence
    private func resolveLastWriteWins<T: Codable>(
        local: T,
        remote: T,
        localUpdatedAt: Date?,
        remoteUpdatedAt: Date?
    ) throws -> T {
        guard let localDate = localUpdatedAt,
              let remoteDate = remoteUpdatedAt else {
            // If timestamps are missing, prefer remote (server is source of truth)
            return remote
        }

        // Compare timestamps - more recent wins
        if localDate > remoteDate {
            return local
        } else {
            return remote
        }
    }

    /// First Write Wins: The first update takes precedence (prevents overwriting)
    private func resolveFirstWriteWins<T: Codable>(
        local: T,
        remote: T,
        localUpdatedAt: Date?,
        remoteUpdatedAt: Date?
    ) throws -> T {
        guard let localDate = localUpdatedAt,
              let remoteDate = remoteUpdatedAt else {
            // If timestamps are missing, prefer remote (server is source of truth)
            return remote
        }

        // Compare timestamps - older wins
        if localDate < remoteDate {
            return local
        } else {
            return remote
        }
    }

    /// Field Level Merging: Merges non-conflicting fields, prefers local for conflicts
    private func resolveFieldLevelMerging<T: Codable>(
        local: T,
        remote: T,
        localUpdatedAt: Date?,
        remoteUpdatedAt: Date?
    ) throws -> T {
        // Encode both versions to dictionaries
        let localEncoder = JSONEncoder()
        let remoteEncoder = JSONEncoder()

        guard let localData = try? localEncoder.encode(local),
              let remoteData = try? remoteEncoder.encode(remote),
              let localDict = try? JSONSerialization.jsonObject(with: localData) as? [String: Any],
              let remoteDict = try? JSONSerialization.jsonObject(with: remoteData) as? [String: Any] else {
            // Fallback to last write wins if encoding fails
            return try self.resolveLastWriteWins(
                local: local,
                remote: remote,
                localUpdatedAt: localUpdatedAt,
                remoteUpdatedAt: remoteUpdatedAt
            )
        }

        // Merge dictionaries - local takes precedence for conflicts
        var mergedDict = remoteDict
        for (key, value) in localDict {
            // Skip metadata fields that should always come from server
            if key == "objectId" || key == "createdAt" || key == "updatedAt" {
                continue
            }

            // Merge arrays by combining unique elements
            if let localArray = value as? [Any],
               let remoteArray = mergedDict[key] as? [Any] {
                // Simple merge: combine arrays and remove duplicates based on first element comparison
                var combined = remoteArray
                for localItem in localArray {
                    if !combined.contains(where: { compareValues($0, localItem) }) {
                        combined.append(localItem)
                    }
                }
                mergedDict[key] = combined
            } else {
                // For non-array values, local takes precedence
                mergedDict[key] = value
            }
        }

        // Decode merged dictionary back to type T
        let mergedData = try JSONSerialization.data(withJSONObject: mergedDict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: mergedData)
    }

    /// Compares two values for equality (used in array merging)
    private func compareValues(_ a: Any, _ b: Any) -> Bool {
        // Simple comparison - can be enhanced for complex types
        if let aString = a as? String, let bString = b as? String {
            return aString == bString
        }
        if let aInt = a as? Int, let bInt = b as? Int {
            return aInt == bInt
        }
        if let aDouble = a as? Double, let bDouble = b as? Double {
            return aDouble == bDouble
        }
        if let aDict = a as? [String: Any], let bDict = b as? [String: Any] {
            return NSDictionary(dictionary: aDict).isEqual(to: bDict)
        }
        return false
    }
}

// MARK: - Conflict Resolution Error

enum ConflictResolutionError: LocalizedError, Sendable {
    case manualResolutionRequired(localDescription: String, remoteDescription: String)
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .manualResolutionRequired:
            return "Manual conflict resolution required"
        case .encodingFailed:
            return "Failed to encode object for conflict resolution"
        case .decodingFailed:
            return "Failed to decode resolved object"
        }
    }
}

// MARK: - Conflict Detection Helper

struct ConflictDetector {
    /// Detects if there's a conflict between local and remote versions
    /// - Parameters:
    ///   - localUpdatedAt: Timestamp of local update
    ///   - remoteUpdatedAt: Timestamp of remote update
    ///   - localVersion: Optional version number for local
    ///   - remoteVersion: Optional version number for remote
    /// - Returns: True if a conflict is detected
    static func hasConflict(
        localUpdatedAt: Date?,
        remoteUpdatedAt: Date?,
        localVersion: Int? = nil,
        remoteVersion: Int? = nil
    ) -> Bool {
        // If both have timestamps and they're different, there's a conflict
        if let localDate = localUpdatedAt,
           let remoteDate = remoteUpdatedAt {
            // Allow small time differences (less than 1 second) to account for clock skew
            let timeDifference = abs(localDate.timeIntervalSince(remoteDate))
            if timeDifference > 1.0 {
                return true
            }
        }

        // If version numbers are provided and different, there's a conflict
        if let localVer = localVersion,
           let remoteVer = remoteVersion,
           localVer != remoteVer {
            return true
        }

        return false
    }
}
