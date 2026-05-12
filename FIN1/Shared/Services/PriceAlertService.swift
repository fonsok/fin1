import Foundation
import Combine

// MARK: - Price Alert Service Protocol
/// Protocol for managing price alerts
@MainActor
protocol PriceAlertServiceProtocol: ObservableObject {
    /// Gets all active alerts for the current user
    var activeAlerts: [PriceAlert] { get }

    /// Gets all alerts (including triggered/cancelled) for the current user
    var allAlerts: [PriceAlert] { get }

    /// Creates a new price alert
    func createAlert(
        symbol: String,
        alertType: PriceAlertType,
        thresholdPrice: Double?,
        thresholdChangePercent: Double?,
        expiresAt: Date?,
        notes: String?
    ) async throws -> PriceAlert

    /// Updates an existing alert
    func updateAlert(_ alert: PriceAlert) async throws

    /// Deletes an alert
    func deleteAlert(_ alertId: String) async throws

    /// Enables/disables an alert
    func setAlertEnabled(_ alertId: String, enabled: Bool) async throws

    /// Checks if any alerts should be triggered based on current market data
    func checkAlerts(for symbol: String, currentPrice: Double, previousPrice: Double?) async

    /// Loads alerts from Parse Server
    func loadAlerts() async throws

    /// Syncs pending alerts to backend (for background synchronization)
    func syncToBackend() async
}

// MARK: - Price Alert Service Implementation
/// Service for managing price alerts with Live Query support
@MainActor
final class PriceAlertService: PriceAlertServiceProtocol {

    // MARK: - Published Properties

    @Published var activeAlerts: [PriceAlert] = []
    @Published var allAlerts: [PriceAlert] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    let parseAPIClient: (any ParseAPIClientProtocol)?
    let parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?
    let marketDataService: (any MarketDataServiceProtocol)?
    let userService: (any UserServiceProtocol)?
    var liveQuerySubscription: LiveQuerySubscription?
    var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        parseAPIClient: (any ParseAPIClientProtocol)? = nil,
        parseLiveQueryClient: (any ParseLiveQueryClientProtocol)? = nil,
        marketDataService: (any MarketDataServiceProtocol)? = nil,
        userService: (any UserServiceProtocol)? = nil
    ) {
        self.parseAPIClient = parseAPIClient
        self.parseLiveQueryClient = parseLiveQueryClient
        self.marketDataService = marketDataService
        self.userService = userService
        setupNotificationObserver()
    }

}

// MARK: - Notification Names

extension Notification.Name {
    static let priceAlertTriggered = Notification.Name("priceAlertTriggered")
}
