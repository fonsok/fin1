import Foundation
import SwiftUI

// MARK: - Mirror-Basis Drift Health View-Model
//
// Drives the "System Health → Mirror-Basis Drift" section in the iOS admin
// dashboard. The section replaces the previous SSH-only workflow: instead of
// tailing `~/fin1-server/logs/mirror-basis-drift.log` the admin now sees the
// latest snapshot straight in the app.
//
// Design notes:
//   * Pure read-only. The weekly cron (see
//     `scripts/run-mirror-basis-drift-check.sh`) authors the snapshot; this
//     VM just loads it.
//   * Graceful when offline / unauthenticated: we surface the error once and
//     leave the last successful snapshot on screen.
//   * No polling — admins explicitly pull-to-refresh. The cron itself runs
//     weekly so automatic polling would mostly repaint the same values.

@MainActor
final class MirrorBasisDriftHealthViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(message: String)
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var status: MirrorBasisDriftStatus?

    private let service: (any OpsHealthAPIServiceProtocol)?

    init(service: (any OpsHealthAPIServiceProtocol)?) {
        self.service = service
    }

    var overall: String {
        status?.overall ?? "unknown"
    }

    var badgeColor: Color {
        switch overall {
        case "healthy":
            return AppTheme.successGreen
        case "degraded":
            return AppTheme.accentOrange
        case "down":
            return AppTheme.accentRed
        default:
            return AppTheme.fontColor.opacity(0.4)
        }
    }

    var isLoading: Bool { state == .loading }

    /// Human-friendly "X days ago" string, falling back to ISO when parsing fails.
    var runAtDisplay: String {
        guard let runAt = status?.runAt else { return "—" }
        guard let date = Self.parseIsoDate(runAt) else { return runAt }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func load() async {
        guard let service = service else {
            state = .failed(message: "Parse API client unavailable")
            return
        }
        state = .loading
        do {
            let result = try await service.fetchMirrorBasisDriftStatus()
            status = result
            state = .loaded
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    private static func parseIsoDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
