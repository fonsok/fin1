import Foundation
import os.log
import SwiftUI

// MARK: - Performance Monitor
/// Comprehensive performance monitoring for the FIN1 app
@MainActor
final class AppPerformanceMonitor: ObservableObject {
    static let shared = AppPerformanceMonitor()

    @Published var isEnabled = true
    @Published var metrics: [String: PerformanceMetric] = [:]

    private let logger = Logger(subsystem: "com.fin.app", category: "Performance")
    private var startTimes: [String: Date] = [:]

    init() {
        // Enable performance monitoring in debug builds
        #if DEBUG
        self.isEnabled = true
        #else
        self.isEnabled = false
        #endif
    }

    // MARK: - Timing Methods

    func startTiming(_ operation: String) {
        guard self.isEnabled else { return }
        self.startTimes[operation] = Date()
        self.logger.debug("⏱️ Started timing: \(operation)")
    }

    func endTiming(_ operation: String) -> TimeInterval? {
        guard self.isEnabled,
              let startTime = startTimes.removeValue(forKey: operation) else {
            return nil
        }

        let duration = Date().timeIntervalSince(startTime)
        self.updateMetric(operation, duration: duration)

        self.logger.debug("⏱️ Completed timing: \(operation) - \(String(format: "%.3f", duration))s")
        return duration
    }

    func measure<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        self.startTiming(operation)
        defer { _ = endTiming(operation) }
        return try block()
    }

    func measureAsync<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        self.startTiming(operation)
        defer { _ = endTiming(operation) }
        return try await block()
    }

    // MARK: - Memory Monitoring

    func logMemoryUsage(_ context: String) {
        guard self.isEnabled else { return }

        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let memoryMB = Double(memoryInfo.resident_size) / 1_024.0 / 1_024.0
            self.logger.debug("🧠 Memory usage (\(context)): \(String(format: "%.2f", memoryMB)) MB")

            // Alert if memory usage is high
            if memoryMB > 200 {
                self.logger.warning("⚠️ High memory usage detected: \(String(format: "%.2f", memoryMB)) MB")
            }
        }
    }

    // MARK: - View Performance

    func trackViewAppear(_ viewName: String) {
        guard self.isEnabled else { return }
        self.logger.debug("👁️ View appeared: \(viewName)")
        self.updateMetric("view_\(viewName)_appear", duration: 0)
    }

    func trackViewDisappear(_ viewName: String) {
        guard self.isEnabled else { return }
        self.logger.debug("👁️ View disappeared: \(viewName)")
        self.updateMetric("view_\(viewName)_disappear", duration: 0)
    }

    // MARK: - Network Performance

    func trackNetworkRequest(_ endpoint: String, duration: TimeInterval, success: Bool) {
        guard self.isEnabled else { return }

        let status = success ? "success" : "failure"
        self.logger.debug("🌐 Network request: \(endpoint) - \(String(format: "%.3f", duration))s - \(status)")

        self.updateMetric("network_\(endpoint)_\(status)", duration: duration)

        // Alert on slow network requests
        if duration > 5.0 {
            self.logger.warning("⚠️ Slow network request: \(endpoint) - \(String(format: "%.3f", duration))s")
        }
    }

    // MARK: - Database Performance

    func trackDatabaseOperation(_ operation: String, duration: TimeInterval, recordCount: Int? = nil) {
        guard self.isEnabled else { return }

        let countInfo = recordCount.map { " (\($0) records)" } ?? ""
        self.logger.debug("💾 Database operation: \(operation) - \(String(format: "%.3f", duration))s\(countInfo)")

        self.updateMetric("db_\(operation)", duration: duration)

        // Alert on slow database operations
        if duration > 2.0 {
            self.logger.warning("⚠️ Slow database operation: \(operation) - \(String(format: "%.3f", duration))s")
        }
    }

    // MARK: - Private Methods

    private func updateMetric(_ operation: String, duration: TimeInterval) {
        if let existing = metrics[operation] {
            self.metrics[operation] = PerformanceMetric(
                operation: operation,
                totalDuration: existing.totalDuration + duration,
                callCount: existing.callCount + 1,
                averageDuration: (existing.totalDuration + duration) / Double(existing.callCount + 1),
                minDuration: min(existing.minDuration, duration),
                maxDuration: max(existing.maxDuration, duration),
                lastUpdated: Date()
            )
        } else {
            self.metrics[operation] = PerformanceMetric(
                operation: operation,
                totalDuration: duration,
                callCount: 1,
                averageDuration: duration,
                minDuration: duration,
                maxDuration: duration,
                lastUpdated: Date()
            )
        }
    }

    // MARK: - Reporting

    func generateReport() -> String {
        var report = "📊 Performance Report\n"
        report += "==================\n\n"

        let sortedMetrics = self.metrics.values.sorted { $0.averageDuration > $1.averageDuration }

        for metric in sortedMetrics.prefix(10) {
            report += "\(metric.operation):\n"
            report += "  Average: \(String(format: "%.3f", metric.averageDuration))s\n"
            report += "  Min: \(String(format: "%.3f", metric.minDuration))s\n"
            report += "  Max: \(String(format: "%.3f", metric.maxDuration))s\n"
            report += "  Calls: \(metric.callCount)\n\n"
        }

        return report
    }

    func clearMetrics() {
        self.metrics.removeAll()
        self.logger.debug("🧹 Performance metrics cleared")
    }
}

// MARK: - Performance Metric Model
struct PerformanceMetric {
    let operation: String
    let totalDuration: TimeInterval
    let callCount: Int
    let averageDuration: TimeInterval
    let minDuration: TimeInterval
    let maxDuration: TimeInterval
    let lastUpdated: Date
}

// MARK: - Performance Monitor View Modifier
struct PerformanceMonitorModifier: ViewModifier {
    let viewName: String
    @StateObject private var monitor = AppPerformanceMonitor.shared

    func body(content: Content) -> some View {
        content
            .onAppear {
                self.monitor.trackViewAppear(self.viewName)
            }
            .onDisappear {
                self.monitor.trackViewDisappear(self.viewName)
            }
    }
}

// MARK: - View Extension
extension View {
    func performanceMonitor(_ viewName: String) -> some View {
        modifier(PerformanceMonitorModifier(viewName: viewName))
    }
}

// MARK: - Performance Debug View
struct AppPerformanceDebugView: View {
    @StateObject private var monitor = AppPerformanceMonitor.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Settings") {
                    Toggle("Enable Monitoring", isOn: self.$monitor.isEnabled)

                    Button("Clear Metrics") {
                        self.monitor.clearMetrics()
                    }
                    .foregroundColor(.red)
                }

                Section("Metrics") {
                    ForEach(Array(self.monitor.metrics.keys.sorted()), id: \.self) { key in
                        if let metric = monitor.metrics[key] {
                            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                                Text(metric.operation)
                                    .font(ResponsiveDesign.headlineFont())

                                HStack {
                                    Text("Avg: \(String(format: "%.3f", metric.averageDuration))s")
                                    Spacer()
                                    Text("Calls: \(metric.callCount)")
                                }
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(.secondary)

                                HStack {
                                    Text("Min: \(String(format: "%.3f", metric.minDuration))s")
                                    Spacer()
                                    Text("Max: \(String(format: "%.3f", metric.maxDuration))s")
                                }
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, ResponsiveDesign.spacing(2))
                        }
                    }
                }
            }
            .navigationTitle("Performance Monitor")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
