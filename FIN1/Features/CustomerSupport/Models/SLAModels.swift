import Foundation
import SwiftUI

// MARK: - SLA Configuration

/// Service Level Agreement configuration
struct SLAConfiguration {
    /// First response time targets (in hours)
    let firstResponseTargets: [SupportTicket.TicketPriority: TimeInterval]

    /// Resolution time targets (in hours)
    let resolutionTargets: [SupportTicket.TicketPriority: TimeInterval]

    /// Warning threshold (percentage of time remaining before warning)
    let warningThreshold: Double  // e.g., 0.25 = warn when 25% time left

    static let `default` = SLAConfiguration(
        firstResponseTargets: [
            .urgent: 1,      // 1 hour
            .high: 4,        // 4 hours
            .medium: 8,      // 8 hours
            .low: 24         // 24 hours
        ],
        resolutionTargets: [
            .urgent: 4,      // 4 hours
            .high: 24,       // 24 hours (1 day)
            .medium: 48,     // 48 hours (2 days)
            .low: 72         // 72 hours (3 days)
        ],
        warningThreshold: 0.25
    )
}

// MARK: - SLA Status

enum SLAStatus: String {
    case onTrack = "Im Zeitplan"
    case warning = "Warnung"
    case breached = "Überschritten"
    case paused = "Pausiert"
    case completed = "Erfüllt"

    var color: Color {
        switch self {
        case .onTrack: return AppTheme.accentGreen
        case .warning: return AppTheme.accentOrange
        case .breached: return AppTheme.accentRed
        case .paused: return AppTheme.fontColor.opacity(0.5)
        case .completed: return AppTheme.accentLightBlue
        }
    }

    var icon: String {
        switch self {
        case .onTrack: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .breached: return "xmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.seal.fill"
        }
    }
}

// MARK: - SLA Info

struct SLAInfo {
    let firstResponseStatus: SLAStatus
    let firstResponseTimeRemaining: TimeInterval?
    let firstResponseDeadline: Date?

    let resolutionStatus: SLAStatus
    let resolutionTimeRemaining: TimeInterval?
    let resolutionDeadline: Date?

    var overallStatus: SLAStatus {
        // If either is breached, overall is breached
        if firstResponseStatus == .breached || resolutionStatus == .breached {
            return .breached
        }
        // If either is warning, overall is warning
        if firstResponseStatus == .warning || resolutionStatus == .warning {
            return .warning
        }
        // If both completed, overall is completed
        if firstResponseStatus == .completed && resolutionStatus == .completed {
            return .completed
        }
        // If either is paused, overall is paused
        if firstResponseStatus == .paused || resolutionStatus == .paused {
            return .paused
        }
        return .onTrack
    }

    var mostUrgentTimeRemaining: TimeInterval? {
        let times = [firstResponseTimeRemaining, resolutionTimeRemaining].compactMap { $0 }
        return times.min()
    }

    var formattedTimeRemaining: String? {
        guard let time = mostUrgentTimeRemaining else { return nil }

        if time <= 0 {
            return "Überfällig"
        }

        let hours = Int(time / 3600)
        let minutes = Int((time.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 24 {
            let days = hours / 24
            return "\(days) Tag\(days == 1 ? "" : "e")"
        } else if hours > 0 {
            return "\(hours) Std. \(minutes) Min."
        } else {
            return "\(minutes) Min."
        }
    }
}

// MARK: - SupportTicket SLA Extension

extension SupportTicket {

    /// Calculate SLA information for this ticket
    func getSLAInfo(config: SLAConfiguration = .default) -> SLAInfo {
        let now = Date()

        // First Response SLA
        let firstResponseTarget = config.firstResponseTargets[priority] ?? 24
        let firstResponseDeadline = createdAt.addingTimeInterval(firstResponseTarget * 3600)
        let hasFirstResponse = responses.contains { !$0.isInternal && $0.agentId != userId }

        let firstResponseStatus: SLAStatus
        let firstResponseTimeRemaining: TimeInterval?

        if hasFirstResponse {
            firstResponseStatus = .completed
            firstResponseTimeRemaining = nil
        } else if status == .waitingForCustomer {
            firstResponseStatus = .paused
            firstResponseTimeRemaining = nil
        } else if now > firstResponseDeadline {
            firstResponseStatus = .breached
            firstResponseTimeRemaining = firstResponseDeadline.timeIntervalSince(now)
        } else {
            let remaining = firstResponseDeadline.timeIntervalSince(now)
            let total = firstResponseTarget * 3600
            if remaining / total <= config.warningThreshold {
                firstResponseStatus = .warning
            } else {
                firstResponseStatus = .onTrack
            }
            firstResponseTimeRemaining = remaining
        }

        // Resolution SLA
        let resolutionTarget = config.resolutionTargets[priority] ?? 72
        let resolutionDeadline = createdAt.addingTimeInterval(resolutionTarget * 3600)

        let resolutionStatus: SLAStatus
        let resolutionTimeRemaining: TimeInterval?

        if status == .resolved || status == .closed {
            resolutionStatus = .completed
            resolutionTimeRemaining = nil
        } else if status == .waitingForCustomer {
            resolutionStatus = .paused
            resolutionTimeRemaining = nil
        } else if now > resolutionDeadline {
            resolutionStatus = .breached
            resolutionTimeRemaining = resolutionDeadline.timeIntervalSince(now)
        } else {
            let remaining = resolutionDeadline.timeIntervalSince(now)
            let total = resolutionTarget * 3600
            if remaining / total <= config.warningThreshold {
                resolutionStatus = .warning
            } else {
                resolutionStatus = .onTrack
            }
            resolutionTimeRemaining = remaining
        }

        return SLAInfo(
            firstResponseStatus: firstResponseStatus,
            firstResponseTimeRemaining: firstResponseTimeRemaining,
            firstResponseDeadline: firstResponseDeadline,
            resolutionStatus: resolutionStatus,
            resolutionTimeRemaining: resolutionTimeRemaining,
            resolutionDeadline: resolutionDeadline
        )
    }
}

