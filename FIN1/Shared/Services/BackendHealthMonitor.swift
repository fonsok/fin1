import Foundation
import Combine

// MARK: - Backend Health Monitor

/// Monitors backend health and availability
@MainActor
final class BackendHealthMonitor: ObservableObject {
    static let shared = BackendHealthMonitor()

    @Published private(set) var isHealthy = true
    @Published private(set) var lastHealthCheck: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var consecutiveFailures = 0
    @Published private(set) var averageResponseTime: TimeInterval = 0

    struct HealthResponse: Codable {
        let status: String
        let timestamp: String?
        let version: String?
        let cloudCode: Bool?
    }

    private var parseAPIClient: (any ParseAPIClientProtocol)?
    private var healthCheckURL: URL?
    private var applicationId: String?
    private var monitoringTask: Task<Void, Never>?
    private let checkInterval: TimeInterval
    private var responseTimes: [TimeInterval] = []
    private let maxResponseTimeHistory = 100
    private let session = URLSession.shared

    init(checkInterval: TimeInterval = 60.0) {
        self.checkInterval = checkInterval
    }

    /// Configure the Parse API client for health checks
    func configure(parseAPIClient: any ParseAPIClientProtocol) {
        self.parseAPIClient = parseAPIClient
    }

    /// Configure direct health check URL (bypasses CircuitBreaker)
    func configure(parseServerURL: String, applicationId: String) {
        self.healthCheckURL = URL(string: "\(parseServerURL)/functions/health")
        self.applicationId = applicationId
    }

    /// Start monitoring backend health
    func startMonitoring() {
        guard monitoringTask == nil else { return }

        monitoringTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                await self.checkHealth()
                try? await Task.sleep(nanoseconds: UInt64(self.checkInterval * 1_000_000_000))
            }
        }

        #if DEBUG
        print("🏥 BackendHealthMonitor: Started monitoring (interval: \(checkInterval)s)")
        #endif
    }

    /// Stop monitoring backend health
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil

        #if DEBUG
        print("🏥 BackendHealthMonitor: Stopped monitoring")
        #endif
    }

    /// Perform a single health check
    /// Uses direct URLSession request to bypass CircuitBreaker (avoids deadlock)
    func checkHealth() async {
        guard let url = healthCheckURL, let appId = applicationId else {
            // Fallback to ParseAPIClient if direct URL not configured
            await checkHealthViaClient()
            return
        }

        let startTime = Date()

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(appId, forHTTPHeaderField: "X-Parse-Application-Id")
            request.httpBody = try JSONSerialization.data(withJSONObject: [:], options: [])
            request.timeoutInterval = 10

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "HealthCheck", code: -1, userInfo: [NSLocalizedDescriptionKey: "HTTP error"])
            }

            // Verify response contains valid health data
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let status = result["status"] as? String,
               status == "healthy" {

                let duration = Date().timeIntervalSince(startTime)

                await MainActor.run {
                    isHealthy = true
                    lastHealthCheck = Date()
                    lastError = nil
                    consecutiveFailures = 0

                    responseTimes.append(duration)
                    if responseTimes.count > maxResponseTimeHistory {
                        responseTimes.removeFirst()
                    }
                    averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)

                    #if DEBUG
                    print("✅ BackendHealthMonitor: Health check passed (\(String(format: "%.3f", duration))s)")
                    #endif
                }

                // Reset circuit breaker since backend is healthy
                if let apiClient = parseAPIClient {
                    await apiClient.resetCircuitBreaker()
                }
            } else {
                throw NSError(domain: "HealthCheck", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format"])
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)

            await MainActor.run {
                isHealthy = false
                lastHealthCheck = Date()
                lastError = error.localizedDescription
                consecutiveFailures += 1

                responseTimes.append(duration)
                if responseTimes.count > maxResponseTimeHistory {
                    responseTimes.removeFirst()
                }
                averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)

                #if DEBUG
                print("❌ BackendHealthMonitor: Health check failed - \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Fallback health check via ParseAPIClient (goes through CircuitBreaker)
    private func checkHealthViaClient() async {
        guard let apiClient = parseAPIClient else {
            await MainActor.run {
                isHealthy = false
                lastError = "ParseAPIClient not configured"
                lastHealthCheck = Date()
            }
            return
        }

        let startTime = Date()

        do {
            let _: HealthResponse = try await apiClient.callFunction("health", parameters: nil)
            let duration = Date().timeIntervalSince(startTime)

            await MainActor.run {
                isHealthy = true
                lastHealthCheck = Date()
                lastError = nil
                consecutiveFailures = 0

                responseTimes.append(duration)
                if responseTimes.count > maxResponseTimeHistory {
                    responseTimes.removeFirst()
                }
                averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)

                #if DEBUG
                print("✅ BackendHealthMonitor: Health check passed (\(String(format: "%.3f", duration))s)")
                #endif
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)

            await MainActor.run {
                isHealthy = false
                lastHealthCheck = Date()
                lastError = error.localizedDescription
                consecutiveFailures += 1

                responseTimes.append(duration)
                if responseTimes.count > maxResponseTimeHistory {
                    responseTimes.removeFirst()
                }
                averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)

                #if DEBUG
                print("❌ BackendHealthMonitor: Health check failed - \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Get health status summary
    func getHealthStatus() -> HealthStatus {
        return HealthStatus(
            isHealthy: isHealthy,
            lastCheck: lastHealthCheck,
            consecutiveFailures: consecutiveFailures,
            averageResponseTime: averageResponseTime,
            lastError: lastError
        )
    }

    struct HealthStatus {
        let isHealthy: Bool
        let lastCheck: Date?
        let consecutiveFailures: Int
        let averageResponseTime: TimeInterval
        let lastError: String?
    }
}

// MARK: - Health Check Fallback

extension BackendHealthMonitor {
    /// Alternative health check using a simple fetch operation
    /// Falls back to this if health Cloud Function is not available
    func checkHealthFallback() async {
        guard let apiClient = parseAPIClient else {
            await MainActor.run {
                isHealthy = false
                lastError = "ParseAPIClient not configured"
                lastHealthCheck = Date()
            }
            return
        }

        let startTime = Date()

        do {
            // Try a lightweight operation: fetch user count or server info
            // This is a fallback if health function doesn't exist
            let _: [String] = try await apiClient.fetchObjects(
                className: "_User",
                query: nil,
                include: nil,
                orderBy: nil,
                limit: 1
            )

            let duration = Date().timeIntervalSince(startTime)

            await MainActor.run {
                isHealthy = true
                lastHealthCheck = Date()
                lastError = nil
                consecutiveFailures = 0

                responseTimes.append(duration)
                if responseTimes.count > maxResponseTimeHistory {
                    responseTimes.removeFirst()
                }
                averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
            }
        } catch {
            // If fallback also fails, try the main health check
            await checkHealth()
        }
    }
}
