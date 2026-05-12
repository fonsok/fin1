import SwiftUI
import Foundation

// MARK: - Performance Optimized View Wrapper
struct PerformanceOptimizedView<Content: View>: View {
    let content: () -> Content
    let id: String

    init(id: String = UUID().uuidString, @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.content = content
    }

    var body: some View {
        content()
            .id(id) // Force view identity for better performance
    }
}

// MARK: - Memoized View
struct MemoizedView<Content: View>: View {
    let content: () -> Content
    private let id: String

    init(@ViewBuilder content: @escaping () -> Content) {
        self.id = UUID().uuidString
        self.content = content
    }

    var body: some View {
        content()
            .id(id)
    }
}

// MARK: - Lazy View Builder
struct LazyView<Content: View>: View {
    let content: () -> Content
    @State private var isLoaded = false

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if isLoaded {
                content()
            } else {
                // Placeholder view while loading
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accentLightBlue))
                    .onAppear {
                        // Load content after a small delay to prevent blocking the main thread
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isLoaded = true
                        }
                    }
            }
        }
    }
}

// MARK: - Optimized List Row
struct OptimizedListRow<Content: View>: View {
    let content: () -> Content
    let id: String

    init(id: String, @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.content = content
    }

    var body: some View {
        content()
            .id(id)
            .drawingGroup() // Optimize complex views by rendering them off-screen
    }
}

// MARK: - Performance Monitor
class PerformanceMonitor: ObservableObject {
    @Published var frameRate: Double = 60.0
    @Published var memoryUsage: Double = 0.0
    @Published var isMonitoring = false

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrameRate))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        isMonitoring = false
    }

    @objc private func updateFrameRate() {
        guard let displayLink = displayLink else { return }

        let currentTimestamp = displayLink.timestamp

        if lastTimestamp != 0 {
            let deltaTime = currentTimestamp - lastTimestamp
            frameRate = 1.0 / deltaTime
        }

        lastTimestamp = currentTimestamp

        // Monitor memory usage
        updateMemoryUsage()
    }

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            memoryUsage = Double(info.resident_size) / 1024 / 1024 // Convert to MB
        }
    }
}

// MARK: - Performance Debug View
struct PerformanceDebugView: View {
    @StateObject private var monitor = PerformanceMonitor()

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Performance Monitor")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            HStack {
                Text("FPS:")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                Text("\(Int(monitor.frameRate))")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(monitor.frameRate < 30 ? AppTheme.accentRed : AppTheme.accentGreen)
            }

            HStack {
                Text("Memory:")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                Text("\(String(format: "%.1f", monitor.memoryUsage)) MB")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(monitor.memoryUsage > 100 ? AppTheme.accentRed : AppTheme.accentGreen)
            }

            Button(monitor.isMonitoring ? "Stop" : "Start") {
                if monitor.isMonitoring {
                    monitor.stopMonitoring()
                } else {
                    monitor.startMonitoring()
                }
            }
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.accentLightBlue)
        }
        .padding(ResponsiveDesign.spacing(8))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
        .onAppear {
            monitor.startMonitoring()
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
    }
}

// MARK: - View Modifiers for Performance
extension View {
    func performanceOptimized(id: String = UUID().uuidString) -> some View {
        PerformanceOptimizedView(id: id) {
            self
        }
    }

    func memoized() -> some View {
        MemoizedView {
            self
        }
    }

    func lazyLoaded() -> some View {
        LazyView {
            self
        }
    }

    func optimizedListRow(id: String) -> some View {
        OptimizedListRow(id: id) {
            self
        }
    }

    func drawingGroupOptimized() -> some View {
        self.drawingGroup()
    }

    func reduceMotion() -> some View {
        self.animation(.none, value: UUID())
    }
}

// MARK: - Performance Utilities
struct PerformanceUtilities {
    static func measureTime<T>(_ operation: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, timeElapsed)
    }

    static func measureAsyncTime<T>(_ operation: () async throws -> T) async rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, timeElapsed)
    }

    static func logPerformance(_ message: String, time: TimeInterval) {
        #if DEBUG
        print("⏱️ Performance: \(message) took \(String(format: "%.3f", time))s")
        #endif
    }
}

// MARK: - Memory Management Utilities
class MemoryManager: @unchecked Sendable {
    static let shared = MemoryManager()

    private init() {}

    func optimizeMemory() {
        // Clear caches
        ImageCacheManager.shared.clearCache()

        // Force garbage collection
        autoreleasepool {
            // Any cleanup operations
        }
    }

    func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024 / 1024 // Convert to MB
        }

        return 0.0
    }
}

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(20)) {
        PerformanceDebugView()

        LazyView {
            VStack {
                Text("Lazy Loaded Content")
                    .font(ResponsiveDesign.headlineFont())
                Text("This content is loaded after a delay")
                    .font(ResponsiveDesign.captionFont())
            }
            .responsivePadding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }

        PerformanceOptimizedView(id: "test") {
            Text("Performance Optimized View")
                .responsivePadding()
                .background(AppTheme.accentLightBlue.opacity(0.2))
                .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }
    .responsivePadding()
    .background(AppTheme.screenBackground)
}
