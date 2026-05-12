import Foundation
import Combine

// MARK: - Event Types
/// Centralized event system for loose coupling between services
/// Replaces direct service-to-service dependencies with event-driven communication

protocol AppEvent {
    var id: UUID { get }
    var timestamp: Date { get }
}

// MARK: - Trading Events
struct OrderCreatedEvent: AppEvent {
    let id = UUID()
    let timestamp = Date()
    let orderId: String
    let orderType: OrderType
    let symbol: String
    let quantity: Int
    let price: Double
}

struct OrderCompletedEvent: AppEvent {
    let id = UUID()
    let timestamp = Date()
    let orderId: String
    let orderType: OrderType
    let symbol: String
    let quantity: Int
    let price: Double
}

struct TradeCreatedEvent: AppEvent {
    let id = UUID()
    let timestamp = Date()
    let tradeId: String
    let tradeNumber: Int
    let symbol: String
    let buyOrderId: String
}

struct TradeCompletedEvent: AppEvent {
    let id = UUID()
    let timestamp = Date()
    let tradeId: String
    let tradeNumber: Int
    let symbol: String
    let totalPnL: Double
}

struct InvoiceCreatedEvent: AppEvent {
    let id = UUID()
    let timestamp = Date()
    let invoiceId: String
    let tradeId: String?
    let orderId: String
    let transactionType: TransactionType
    let amount: Double
}

// MARK: - User Events
struct UserSignedInEvent: AppEvent {
    let id = UUID()
    let timestamp = Date()
    let userId: String
    let userRole: UserRole
}

struct UserSignedOutEvent: AppEvent {
    let id = UUID()
    let timestamp = Date()
    let userId: String
}

// MARK: - Depot Events
struct DepotValueUpdatedEvent: AppEvent {
    let id = UUID()
    let timestamp = Date()
    let newValue: Double
    let previousValue: Double
}

struct HoldingUpdatedEvent: AppEvent {
    let id = UUID()
    let timestamp = Date()
    let holdingId: String
    let remainingQuantity: Int
    let soldQuantity: Int
}

// MARK: - Event Bus
/// Centralized event bus for decoupled communication between services
final class EventBus: ObservableObject, @unchecked Sendable {
    static let shared = EventBus()

    private let eventSubject = PassthroughSubject<AppEvent, Never>()
    private var cancellables = Set<AnyCancellable>()

    init() {}

    // MARK: - Event Publishing

    /// Publishes an event to all subscribers
    func publish<T: AppEvent>(_ event: T) {
        print("📡 EventBus: Publishing \(type(of: event)) - \(event.id)")
        eventSubject.send(event)
    }

    // MARK: - Event Subscription

    /// Subscribes to events of a specific type
    func subscribe<T: AppEvent>(to eventType: T.Type) -> AnyPublisher<T, Never> {
        return eventSubject
            .compactMap { $0 as? T }
            .eraseToAnyPublisher()
    }

    /// Subscribes to all events
    func subscribeToAll() -> AnyPublisher<AppEvent, Never> {
        return eventSubject.eraseToAnyPublisher()
    }

    // MARK: - Convenience Methods

    /// Publishes an order created event
    func publishOrderCreated(orderId: String, orderType: OrderType, symbol: String, quantity: Int, price: Double) {
        let event = OrderCreatedEvent(
            orderId: orderId,
            orderType: orderType,
            symbol: symbol,
            quantity: quantity,
            price: price
        )
        publish(event)
    }

    /// Publishes an order completed event
    func publishOrderCompleted(orderId: String, orderType: OrderType, symbol: String, quantity: Int, price: Double) {
        let event = OrderCompletedEvent(
            orderId: orderId,
            orderType: orderType,
            symbol: symbol,
            quantity: quantity,
            price: price
        )
        publish(event)
    }

    /// Publishes a trade created event
    func publishTradeCreated(tradeId: String, tradeNumber: Int, symbol: String, buyOrderId: String) {
        let event = TradeCreatedEvent(
            tradeId: tradeId,
            tradeNumber: tradeNumber,
            symbol: symbol,
            buyOrderId: buyOrderId
        )
        publish(event)
    }

    /// Publishes a trade completed event
    func publishTradeCompleted(tradeId: String, tradeNumber: Int, symbol: String, totalPnL: Double) {
        let event = TradeCompletedEvent(
            tradeId: tradeId,
            tradeNumber: tradeNumber,
            symbol: symbol,
            totalPnL: totalPnL
        )
        publish(event)
    }

    /// Publishes an invoice created event
    func publishInvoiceCreated(invoiceId: String, tradeId: String?, orderId: String, transactionType: TransactionType, amount: Double) {
        let event = InvoiceCreatedEvent(
            invoiceId: invoiceId,
            tradeId: tradeId,
            orderId: orderId,
            transactionType: transactionType,
            amount: amount
        )
        publish(event)
    }

    /// Publishes a user signed in event
    func publishUserSignedIn(userId: String, userRole: UserRole) {
        let event = UserSignedInEvent(userId: userId, userRole: userRole)
        publish(event)
    }

    /// Publishes a user signed out event
    func publishUserSignedOut(userId: String) {
        let event = UserSignedOutEvent(userId: userId)
        publish(event)
    }

    /// Publishes a depot value updated event
    func publishDepotValueUpdated(newValue: Double, previousValue: Double) {
        let event = DepotValueUpdatedEvent(newValue: newValue, previousValue: previousValue)
        publish(event)
    }

    /// Publishes a holding updated event
    func publishHoldingUpdated(holdingId: String, remainingQuantity: Int, soldQuantity: Int) {
        let event = HoldingUpdatedEvent(
            holdingId: holdingId,
            remainingQuantity: remainingQuantity,
            soldQuantity: soldQuantity
        )
        publish(event)
    }
}

// MARK: - Event Handler Extension
extension EventHandler {
    /// Convenience method to subscribe to specific event types
    func subscribeToEvents<T: AppEvent>(_ eventType: T.Type, handler: @escaping (T) -> Void) -> AnyCancellable {
        return EventBus.shared.subscribe(to: eventType)
            .sink { event in
                handler(event)
            }
    }
}
