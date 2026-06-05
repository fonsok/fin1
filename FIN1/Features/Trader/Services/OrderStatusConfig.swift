import Foundation

// MARK: - Order Status Configuration
/// Centralized timing for order status progression in the trader UI (buy and sell).
enum OrderStatusConfig {
    /// Delay before each status transition (`submitted` → … → `completed`).
    static let statusStepInterval: TimeInterval = 1.0

    /// Legacy aliases — same value as `statusStepInterval`.
    static let preExecutionStepInterval: TimeInterval = statusStepInterval
    static let postExecutionStepInterval: TimeInterval = statusStepInterval

    /// Statuses where STORNO is still allowed (matches OrderCard `statusValue < 3`).
    static let cancellableStatuses: Set<String> = ["submitted", "1", "suspended", "2", "pending"]

    static func isCancellableDisplayStatus(_ status: String) -> Bool {
        self.cancellableStatuses.contains(status.lowercased())
    }

    /// Sleep duration before advancing **from** the given status.
    static func stepInterval(fromStatus status: String) -> TimeInterval {
        self.statusStepInterval
    }

    static func stepIntervalNanoseconds(fromStatus status: String) -> UInt64 {
        UInt64(self.stepInterval(fromStatus: status) * 1_000_000_000)
    }
}
