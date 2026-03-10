# 🎯 Nächste Schritte für vollständige Backend-Integration - FIN1

**Datum:** 2026-02-05
**Status:** Basis-Integration abgeschlossen ✅
**Ziel:** Production-Ready Backend-Integration

---

## 📊 Aktueller Stand

### ✅ Abgeschlossen (Phase 1-4)
- **Alle Services integriert**: Trade, Investment, Order, Wallet, Documents, User, Watchlist, Filters, Push Tokens, Price Alerts
- **Write-Through Pattern**: Sofortige Synchronisation bei CRUD-Operationen
- **Background Sync**: Parallel-Synchronisation aller Services bei App-Background
- **Parse Server**: Läuft stabil über Nginx (`https://192.168.178.24/parse`); intern Container :1337
- **Live Query**: WebSocket-Verbindung für Echtzeit-Updates (teilweise implementiert)

### ⚠️ Identifizierte Lücken

1. **Fehlende Retry-Logik & Circuit Breaker**
2. **Unvollständige Offline-Unterstützung**
3. **Keine Request-Deduplizierung**
4. **Fehlende Production-Sicherheit (HTTPS/WSS)**
5. **Unvollständiges Monitoring & Observability**
6. **Fehlende Conflict-Resolution bei Concurrent Updates**

---

## 🔴 Priorität 1: Robustheit & Fehlerbehandlung (5-7 Tage)

### 1.1 Retry-Logik mit Exponential Backoff

**Problem:** `ParseAPIClient` hat keine Retry-Logik bei temporären Netzwerkfehlern.

**Lösung:**
```swift
// FIN1/Shared/Services/NetworkRetryPolicy.swift
struct NetworkRetryPolicy {
    static let maxRetries = 3
    static let baseDelay: TimeInterval = 1.0
    static let maxDelay: TimeInterval = 10.0

    static func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        return min(exponentialDelay, maxDelay)
    }

    static func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .timeout, .noConnection:
                return true
            case .serverError(let code):
                // Retry on 5xx errors, not 4xx
                return code >= 500
            default:
                return false
            }
        }

        return false
    }
}
```

**Integration in `ParseAPIClient`:**
```swift
// Erweitere alle Request-Methoden mit Retry-Logik
func fetchObjects<T: Decodable>(...) async throws -> [T] {
    var lastError: Error?

    for attempt in 0...NetworkRetryPolicy.maxRetries {
        do {
            // ... existing request code ...
            return try await performRequest(...)
        } catch {
            lastError = error

            guard NetworkRetryPolicy.shouldRetry(error: error, attempt: attempt) else {
                throw error
            }

            let delay = NetworkRetryPolicy.delay(for: attempt)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            continue
        }
    }

    throw lastError ?? NetworkError.timeout
}
```

**Aufwand:** 2-3 Tage
**Impact:** ⭐⭐⭐⭐⭐ (Kritisch für Production)

---

### 1.2 Circuit Breaker Pattern

**Problem:** Bei wiederholten Backend-Fehlern werden weiterhin Requests gesendet (Ressourcenverschwendung).

**Lösung:**
```swift
// FIN1/Shared/Services/CircuitBreaker.swift
actor CircuitBreaker {
    enum State {
        case closed      // Normal operation
        case open        // Failing, reject requests
        case halfOpen    // Testing if service recovered
    }

    private var state: State = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?

    private let failureThreshold = 5
    private let timeout: TimeInterval = 60.0

    func execute<T>(_ operation: () async throws -> T) async throws -> T {
        switch state {
        case .open:
            guard let lastFailure = lastFailureTime,
                  Date().timeIntervalSince(lastFailure) > timeout else {
                throw ServiceError.serviceUnavailable
            }
            state = .halfOpen

        case .halfOpen, .closed:
            break
        }

        do {
            let result = try await operation()
            await reset()
            return result
        } catch {
            await recordFailure()
            throw error
        }
    }

    private func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()

        if failureCount >= failureThreshold {
            state = .open
        }
    }

    private func reset() {
        failureCount = 0
        state = .closed
        lastFailureTime = nil
    }
}
```

**Integration:**
```swift
// In ParseAPIClient
private let circuitBreaker = CircuitBreaker()

func fetchObjects<T: Decodable>(...) async throws -> [T] {
    return try await circuitBreaker.execute {
        // ... existing request code ...
    }
}
```

**Aufwand:** 2-3 Tage
**Impact:** ⭐⭐⭐⭐ (Wichtig für Production)

---

### 1.3 Request-Deduplizierung

**Problem:** Mehrfache identische Requests werden parallel ausgeführt (z.B. beim schnellen Scrollen).

**Lösung:**
```swift
// FIN1/Shared/Services/RequestDeduplicator.swift
actor RequestDeduplicator {
    private var pendingRequests: [String: Task<Any, Error>] = [:]

    func execute<T: Sendable>(
        key: String,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        // Check if request is already pending
        if let existingTask = pendingRequests[key] {
            return try await existingTask.value as! T
        }

        // Create new task
        let task = Task {
            defer { Task { await removeRequest(key: key) } }
            return try await operation()
        }

        pendingRequests[key] = task

        return try await task.value
    }

    private func removeRequest(key: String) {
        pendingRequests.removeValue(forKey: key)
    }
}
```

**Aufwand:** 1-2 Tage
**Impact:** ⭐⭐⭐ (Performance-Optimierung)

---

## 🟡 Priorität 2: Offline-Unterstützung (4-6 Tage)

### 2.1 Offline-First Queue

**Problem:** Aktuell gibt es nur Fallback zu persisted data, aber keine Queue für Offline-Operationen.

**Lösung:**
```swift
// FIN1/Shared/Services/OfflineOperationQueue.swift
final class OfflineOperationQueue: ObservableObject {
    enum OperationType: String, Codable {
        case create, update, delete
    }

    struct QueuedOperation: Codable, Identifiable {
        let id: String
        let type: OperationType
        let className: String
        let objectId: String?
        let payload: Data
        let createdAt: Date
        let retryCount: Int
    }

    @Published private(set) var pendingOperations: [QueuedOperation] = []
    private let persistenceKey = "offline_operations_queue"

    func enqueue(_ operation: QueuedOperation) {
        pendingOperations.append(operation)
        persistQueue()
    }

    func processQueue() async {
        guard NetworkMonitor.shared.isConnected else { return }

        let operations = pendingOperations
        for operation in operations {
            do {
                try await executeOperation(operation)
                removeOperation(operation.id)
            } catch {
                incrementRetryCount(operation.id)
                if operation.retryCount >= 5 {
                    // Move to failed operations
                    moveToFailed(operation)
                }
            }
        }
    }
}
```

**Integration in App-Lifecycle:**
```swift
// In FIN1App.swift
private func handleAppBecameActive() async {
    // ... existing code ...

    // Process offline queue when app becomes active
    await services.offlineOperationQueue.processQueue()
}
```

**Aufwand:** 3-4 Tage
**Impact:** ⭐⭐⭐⭐ (Wichtig für UX)

---

### 2.2 Conflict-Resolution bei Concurrent Updates

**Problem:** Wenn mehrere Geräte gleichzeitig dasselbe Objekt aktualisieren, gibt es keine Conflict-Resolution.

**Lösung:**
```swift
// FIN1/Shared/Services/ConflictResolutionService.swift
protocol ConflictResolutionServiceProtocol {
    func resolveConflict<T: Codable & Identifiable>(
        local: T,
        remote: T,
        lastModified: Date
    ) async throws -> T
}

final class LastWriteWinsResolver: ConflictResolutionServiceProtocol {
    func resolveConflict<T: Codable & Identifiable>(
        local: T,
        remote: T,
        lastModified: Date
    ) async throws -> T {
        // Simple strategy: Last write wins
        // For production, implement more sophisticated strategies:
        // - Field-level merging
        // - User preference-based resolution
        // - Manual conflict resolution UI
        return remote
    }
}
```

**Aufwand:** 2-3 Tage
**Impact:** ⭐⭐⭐ (Wichtig für Multi-Device-Support)

---

## 🟢 Priorität 3: Production-Sicherheit (3-5 Tage)

### 3.1 HTTPS/WSS Migration

**Problem:** Aktuell HTTP/WS (nicht verschlüsselt) - nicht production-ready.

**Lösung:**
1. **Let's Encrypt Zertifikat einrichten** (wenn Domain vorhanden)
2. **Nginx HTTPS-Konfiguration**:
```nginx
server {
    listen 443 ssl http2;
    server_name fin1.example.com;

    ssl_certificate /etc/letsencrypt/live/fin1.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/fin1.example.com/privkey.pem;

    location /parse {
        proxy_pass http://parse-server:1337/parse;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

3. **iOS ATS-Konfiguration** (nur für Dev):
```xml
<!-- Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>192.168.178.24</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Aufwand:** 2-3 Tage (mit Domain)
**Impact:** ⭐⭐⭐⭐⭐ (Kritisch für Production)

---

### 3.2 Request-Signing & Rate Limiting

**Problem:** Keine Schutzmaßnahmen gegen API-Abuse.

**Lösung:**
```swift
// FIN1/Shared/Services/APIRateLimiter.swift
actor APIRateLimiter {
    private var requestCounts: [String: [Date]] = [:]
    private let maxRequests = 100
    private let timeWindow: TimeInterval = 60.0

    func checkRateLimit(endpoint: String) throws {
        let now = Date()
        let windowStart = now.addingTimeInterval(-timeWindow)

        let requests = requestCounts[endpoint] ?? []
        let recentRequests = requests.filter { $0 > windowStart }

        guard recentRequests.count < maxRequests else {
            throw ServiceError.rateLimited
        }

        requestCounts[endpoint] = recentRequests + [now]
    }
}
```

**Aufwand:** 1-2 Tage
**Impact:** ⭐⭐⭐⭐ (Wichtig für Security)

---

## 🔵 Priorität 4: Monitoring & Observability (3-4 Tage)

### 4.1 Request-Logging & Metrics

**Problem:** Keine zentrale Logging-Infrastruktur für Debugging.

**Lösung:**
```swift
// FIN1/Shared/Services/NetworkLogger.swift
final class NetworkLogger {
    struct LogEntry: Codable {
        let timestamp: Date
        let endpoint: String
        let method: String
        let statusCode: Int?
        let duration: TimeInterval
        let error: String?
    }

    func logRequest(_ entry: LogEntry) {
        // Log to local file for debugging
        // In production: Send to analytics service
        print("🌐 [\(entry.method)] \(entry.endpoint) - \(entry.statusCode ?? 0) - \(String(format: "%.3f", entry.duration))s")

        // Persist for crash reports
        persistLog(entry)
    }
}
```

**Aufwand:** 1-2 Tage
**Impact:** ⭐⭐⭐ (Wichtig für Debugging)

---

### 4.2 Health-Check Monitoring

**Problem:** Keine automatische Überwachung der Backend-Verfügbarkeit.

**Lösung:**
```swift
// FIN1/Shared/Services/BackendHealthMonitor.swift
final class BackendHealthMonitor {
    @Published private(set) var isHealthy = true
    @Published private(set) var lastHealthCheck: Date?

    func startMonitoring(interval: TimeInterval = 60.0) {
        Task {
            while true {
                await checkHealth()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    private func checkHealth() async {
        do {
            let response: HealthResponse = try await apiClient.callFunction("health")
            await MainActor.run {
                isHealthy = response.status == "ok"
                lastHealthCheck = Date()
            }
        } catch {
            await MainActor.run {
                isHealthy = false
                lastHealthCheck = Date()
            }
        }
    }
}
```

**Aufwand:** 1-2 Tage
**Impact:** ⭐⭐⭐ (Wichtig für Production)

---

## 📋 Implementierungs-Roadmap

### Woche 1-2: Robustheit
- [ ] Retry-Logik mit Exponential Backoff
- [ ] Circuit Breaker Pattern
- [ ] Request-Deduplizierung

### Woche 3-4: Offline-Support
- [ ] Offline-Operation-Queue
- [ ] Conflict-Resolution-Service
- [ ] Optimistic Updates

### Woche 5-6: Production-Sicherheit
- [ ] HTTPS/WSS Migration
- [ ] Rate Limiting
- [ ] Request-Signing (optional)

### Woche 7: Monitoring
- [ ] Network-Logging
- [ ] Health-Check-Monitoring
- [ ] Performance-Metrics

---

## 🧪 Testing-Strategie

### Unit Tests
- Retry-Logik: Teste verschiedene Fehlerszenarien
- Circuit Breaker: Teste State-Transitions
- Offline-Queue: Teste Queue-Verarbeitung

### Integration Tests
- End-to-End Sync-Tests
- Conflict-Resolution-Tests
- Offline-Mode-Tests

### Performance Tests
- Request-Deduplizierung: Messung der Request-Reduktion
- Retry-Logik: Messung der Latenz bei Fehlern

---

## 📝 Dokumentation

Nach jeder Implementierung:
1. **Code-Dokumentation**: DocC-Kommentare für neue Services
2. **Architektur-Dokumentation**: Update `.cursor/rules/architecture.md`
3. **Testing-Dokumentation**: Update `.cursor/rules/testing.md`

---

## 🎯 Erfolgs-Kriterien

- ✅ **99.9% Uptime**: Circuit Breaker verhindert Cascading Failures
- ✅ **< 3s Response Time**: Retry-Logik optimiert Latenz
- ✅ **Offline-First**: App funktioniert ohne Internet-Verbindung
- ✅ **HTTPS**: Alle Verbindungen verschlüsselt
- ✅ **Monitoring**: Vollständige Observability

---

## 📚 Referenzen

- **Architektur-Rules**: `.cursor/rules/architecture.md`
- **Backend-Integration**: `Documentation/BACKEND_INTEGRATION_ROADMAP.md`
- **Parse Server Docs**: `backend/README.md`
- **Network Config**: `NETZWERK_KONFIGURATION.md`

---

**Nächster Schritt:** Starte mit Priorität 1.1 (Retry-Logik) - das ist die Basis für alle weiteren Verbesserungen.
