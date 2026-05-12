import Foundation

// MARK: - Ops-Health API Service (Admin observability)
//
// Thin, read-only client for `getMirrorBasisDriftStatus`
// (see `backend/parse-server/cloud/functions/admin/opsHealth.js`). The Cloud
// function is admin-gated and returns the latest snapshot written by the
// weekly `run-mirror-basis-drift-check.sh` cron job, so admins can see the
// reconciliation state from inside the app — no more SSH-tailing of
// `~/fin1-server/logs/mirror-basis-drift.log`.
//
// Kept deliberately small because:
//   * iOS is a pure reader here — no writes.
//   * The Cloud function already enforces `requireAdminRole`.
//   * The payload shape is stable across reloads (see ADR-007 related docs).

protocol OpsHealthAPIServiceProtocol: Sendable {
    /// Fetches the latest mirror-basis drift snapshot from the server.
    /// Returns `nil` only on transport/decoding failures; callers render
    /// `reason` when `status.hasSnapshot == false`.
    func fetchMirrorBasisDriftStatus() async throws -> MirrorBasisDriftStatus
}

/// Decoded payload of `getMirrorBasisDriftStatus`.
///
/// The `overall` value drives the coloured pill in the admin UI:
///   * `healthy`  → green
///   * `degraded` → orange
///   * `down`     → red
///   * `unknown`  → grey (first-run state, no snapshot yet)
struct MirrorBasisDriftStatus: Decodable, Sendable {
    let overall: String
    let hasSnapshot: Bool
    let runAt: String?
    let ageSeconds: Int?
    let healthy: Bool?
    let checkedDocuments: Int?
    let driftedDocuments: Int?
    let nullDerivedCount: Int?
    let commissionRate: Double?
    let epsilonPp: Double?
    let driftSamples: [DriftSample]?
    let reason: String?

    struct DriftSample: Decodable, Sendable {
        let docId: String?
        let investmentId: String?
        let tradeId: String?
        let storedReturnPercentage: Double?
        let derivedReturnPercentage: Double?
        let deltaPp: Double?
        let backfillSource: String?
    }
}

final class OpsHealthAPIService: OpsHealthAPIServiceProtocol, @unchecked Sendable {
    private let apiClient: ParseAPIClientProtocol

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    func fetchMirrorBasisDriftStatus() async throws -> MirrorBasisDriftStatus {
        return try await apiClient.callFunction(
            "getMirrorBasisDriftStatus",
            parameters: nil
        )
    }
}
