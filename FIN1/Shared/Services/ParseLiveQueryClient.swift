import Combine
import Foundation

// MARK: - Parse Live Query Client Protocol
/// Protocol for subscribing to real-time updates from Parse Server
@MainActor
protocol ParseLiveQueryClientProtocol {
    /// Subscribes to changes in a Parse class
    func subscribe<T: Decodable>(
        className: String,
        query: [String: Any]?,
        onUpdate: @escaping (T) -> Void,
        onDelete: ((String) -> Void)?,
        onError: ((Error) -> Void)?
    ) -> LiveQuerySubscription
    
    /// Unsubscribes from a subscription
    func unsubscribe(_ subscription: LiveQuerySubscription)
    
    /// Connects to Parse Live Query server
    func connect() async throws
    
    /// Disconnects from Parse Live Query server
    func disconnect()
}

// MARK: - Live Query Subscription
/// Represents an active subscription to Parse Live Query
struct LiveQuerySubscription: Identifiable {
    let id: String
    let className: String
    let query: [String: Any]?
}

// MARK: - Parse Live Query Client Implementation
/// WebSocket-based client for Parse Server Live Query
/// Provides real-time updates for subscribed Parse classes
@MainActor
final class ParseLiveQueryClient: ParseLiveQueryClientProtocol {
    
    // MARK: - Properties
    
    private let liveQueryURL: String
    private let applicationId: String
    private let sessionToken: String?
    private var webSocketTask: URLSessionWebSocketTask?
    private var subscriptions: [String: LiveQuerySubscription] = [:]
    private var isConnected = false
    private let queue = DispatchQueue(label: "com.fin1.parse.livequery", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        liveQueryURL: String,
        applicationId: String,
        sessionToken: String? = nil
    ) {
        self.liveQueryURL = liveQueryURL
        self.applicationId = applicationId
        self.sessionToken = sessionToken
    }
    
    // MARK: - ParseLiveQueryClientProtocol
    
    func connect() async throws {
        guard !self.isConnected else { return }
        
        // Convert http/https to ws/wss
        let wsURL = self.liveQueryURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
        
        guard let url = URL(string: wsURL) else {
            throw NetworkError.invalidResponse
        }
        
        let session = URLSession(configuration: .default)
        self.webSocketTask = session.webSocketTask(with: url)
        
        // Add headers
        var request = URLRequest(url: url)
        request.setValue(self.applicationId, forHTTPHeaderField: "X-Parse-Application-Id")
        if let sessionToken = sessionToken {
            request.setValue(sessionToken, forHTTPHeaderField: "X-Parse-Session-Token")
        }
        
        self.webSocketTask?.resume()
        self.isConnected = true
        
        // Start receiving messages
        self.receiveMessages()
        
        // Send connect message
        try await self.sendConnectMessage()
    }
    
    func disconnect() {
        self.webSocketTask?.cancel(with: .goingAway, reason: nil)
        self.webSocketTask = nil
        self.isConnected = false
        self.subscriptions.removeAll()
    }
    
    func subscribe<T: Decodable>(
        className: String,
        query: [String: Any]? = nil,
        onUpdate: @escaping (T) -> Void,
        onDelete: ((String) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> LiveQuerySubscription {
        let subscriptionId = UUID().uuidString
        let subscription = LiveQuerySubscription(
            id: subscriptionId,
            className: className,
            query: query
        )
        
        self.subscriptions[subscriptionId] = subscription
        
        // Send subscribe message
        Task {
            do {
                try await self.sendSubscribeMessage(subscription: subscription)
            } catch {
                onError?(error)
            }
        }
        
        // Store callbacks (simplified - in production, use proper callback storage)
        // For now, we'll use a notification-based approach
        
        return subscription
    }
    
    func unsubscribe(_ subscription: LiveQuerySubscription) {
        self.subscriptions.removeValue(forKey: subscription.id)
        
        Task {
            try? await self.sendUnsubscribeMessage(subscriptionId: subscription.id)
        }
    }
    
    // MARK: - Private Methods
    
    private func sendConnectMessage() async throws {
        let message: [String: Any] = [
            "op": "connect",
            "applicationId": applicationId
        ]
        
        if let sessionToken = sessionToken {
            var msg = message
            msg["sessionToken"] = sessionToken
            try await self.sendMessage(msg)
        } else {
            try await self.sendMessage(message)
        }
    }
    
    private func sendSubscribeMessage(subscription: LiveQuerySubscription) async throws {
        var message: [String: Any] = [
            "op": "subscribe",
            "requestId": subscription.id,
            "query": [
                "className": subscription.className
            ]
        ]
        
        if let query = subscription.query {
            message["query"] = [
                "className": subscription.className,
                "where": query
            ]
        }
        
        try await self.sendMessage(message)
    }
    
    private func sendUnsubscribeMessage(subscriptionId: String) async throws {
        let message: [String: Any] = [
            "op": "unsubscribe",
            "requestId": subscriptionId
        ]
        
        try await sendMessage(message)
    }
    
    private func sendMessage(_ message: [String: Any]) async throws {
        guard let webSocketTask = webSocketTask else {
            throw NetworkError.serverError(503) // Service Unavailable
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NetworkError.invalidResponse
        }
        
        let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
        try await webSocketTask.send(wsMessage)
    }
    
    private func receiveMessages() {
        self.webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.receiveMessages()
                case .failure(let error):
                    print("⚠️ Live Query WebSocket error: \(error.localizedDescription)")
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                        try? await self.connect()
                    }
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let op = json["op"] as? String else {
                return
            }
            
            switch op {
            case "connected":
                print("✅ Parse Live Query connected")
            case "subscribed":
                if let requestId = json["requestId"] as? String {
                    print("✅ Subscribed to Live Query: \(requestId)")
                }
            case "create", "update":
                self.handleObjectUpdate(json)
            case "delete":
                self.handleObjectDelete(json)
            case "error":
                if let errorMessage = json["error"] as? String {
                    print("⚠️ Live Query error: \(errorMessage)")
                }
            default:
                break
            }
        case .data:
            break
        @unknown default:
            break
        }
    }
    
    private func handleObjectUpdate(_ json: [String: Any]) {
        // Post notification with updated object
        // Services can subscribe to these notifications
        if let object = json["object"] as? [String: Any],
           let className = object["className"] as? String {
            NotificationCenter.default.post(
                name: .parseLiveQueryObjectUpdated,
                object: nil,
                userInfo: [
                    "className": className,
                    "object": object
                ]
            )
        }
    }
    
    private func handleObjectDelete(_ json: [String: Any]) {
        if let object = json["object"] as? [String: Any],
           let className = object["className"] as? String,
           let objectId = object["objectId"] as? String {
            NotificationCenter.default.post(
                name: .parseLiveQueryObjectDeleted,
                object: nil,
                userInfo: [
                    "className": className,
                    "objectId": objectId
                ]
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let parseLiveQueryObjectUpdated = Notification.Name("parseLiveQueryObjectUpdated")
    static let parseLiveQueryObjectDeleted = Notification.Name("parseLiveQueryObjectDeleted")
}
