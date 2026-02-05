import Foundation
import Combine

// MARK: - Price Alert Service Protocol
/// Protocol for managing price alerts
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
final class PriceAlertService: PriceAlertServiceProtocol {

    // MARK: - Published Properties

    @Published private(set) var activeAlerts: [PriceAlert] = []
    @Published private(set) var allAlerts: [PriceAlert] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let parseAPIClient: (any ParseAPIClientProtocol)?
    private let parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?
    private let marketDataService: (any MarketDataServiceProtocol)?
    private let userService: (any UserServiceProtocol)?
    private var liveQuerySubscription: LiveQuerySubscription?
    private var cancellables = Set<AnyCancellable>()

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

    // MARK: - PriceAlertServiceProtocol

    func createAlert(
        symbol: String,
        alertType: PriceAlertType,
        thresholdPrice: Double?,
        thresholdChangePercent: Double?,
        expiresAt: Date?,
        notes: String?
    ) async throws -> PriceAlert {
        guard let userId = userService?.currentUser?.id else {
            throw AppError.authentication(.tokenExpired)
        }

        let parseAlert = ParsePriceAlert(
            userId: userId,
            symbol: symbol,
            alertType: alertType,
            thresholdPrice: thresholdPrice,
            thresholdChangePercent: thresholdChangePercent,
            expiresAt: expiresAt,
            notes: notes
        )

        // Save to Parse Server
        if let apiClient = parseAPIClient {
            do {
                let response = try await apiClient.createObject(
                    className: "PriceAlert",
                    object: parseAlert
                )

                // Update parseAlert with objectId from response
                let createdAlert = ParsePriceAlert(
                    objectId: response.objectId,
                    userId: parseAlert.userId,
                    symbol: parseAlert.symbol,
                    alertType: parseAlert.alertType,
                    thresholdPrice: parseAlert.thresholdPrice,
                    thresholdChangePercent: parseAlert.thresholdChangePercent,
                    status: parseAlert.status,
                    createdAt: parseAlert.createdAt,
                    triggeredAt: parseAlert.triggeredAt,
                    expiresAt: parseAlert.expiresAt,
                    notificationSent: parseAlert.notificationSent,
                    isEnabled: parseAlert.isEnabled,
                    notes: parseAlert.notes
                )

                let alert = PriceAlert(from: createdAlert)
                await MainActor.run {
                    allAlerts.append(alert)
                    updateActiveAlerts()
                }
                return alert
            } catch {
                // Fallback to local cache if API call fails
                print("⚠️ Failed to create Price Alert in Parse Server: \(error.localizedDescription)")
                let alert = PriceAlert(from: parseAlert)
                await MainActor.run {
                    allAlerts.append(alert)
                    updateActiveAlerts()
                }
                return alert
            }
        } else {
            // Mock implementation - add to local cache
            let alert = PriceAlert(from: parseAlert)
            await MainActor.run {
                allAlerts.append(alert)
                updateActiveAlerts()
            }
            return alert
        }
    }

    func updateAlert(_ alert: PriceAlert) async throws {
        guard let userId = userService?.currentUser?.id,
              userId == alert.userId else {
            throw AppError.authentication(.tokenExpired)
        }

        // Update in Parse Server
        if let apiClient = parseAPIClient, !alert.id.isEmpty {
            do {
                let parseAlert = alert.toParsePriceAlert()
                _ = try await apiClient.updateObject(
                    className: "PriceAlert",
                    objectId: alert.id,
                    object: parseAlert
                )
            } catch {
                print("⚠️ Failed to update Price Alert in Parse Server: \(error.localizedDescription)")
            }
        }

        // Update local cache
        await MainActor.run {
            if let index = allAlerts.firstIndex(where: { $0.id == alert.id }) {
                allAlerts[index] = alert
                updateActiveAlerts()
            }
        }
    }

    func deleteAlert(_ alertId: String) async throws {
        guard userService?.currentUser?.id != nil else {
            throw AppError.authentication(.tokenExpired)
        }

        // Delete from Parse Server
        if let apiClient = parseAPIClient {
            do {
                try await apiClient.deleteObject(
                    className: "PriceAlert",
                    objectId: alertId
                )
            } catch {
                print("⚠️ Failed to delete Price Alert from Parse Server: \(error.localizedDescription)")
                // Continue with local deletion even if API call fails
            }
        }

        // Remove from local cache
        await MainActor.run {
            allAlerts.removeAll { $0.id == alertId }
            updateActiveAlerts()
        }
    }

    func setAlertEnabled(_ alertId: String, enabled: Bool) async throws {
        guard let alert = allAlerts.first(where: { $0.id == alertId }) else {
            throw AppError.service(.dataNotFound)
        }

        // Note: PriceAlert is a struct, so we need to create a new instance
        // For now, we'll update via updateAlert
        let parseAlert = alert.toParsePriceAlert()
        let modifiedParseAlert = ParsePriceAlert(
            objectId: parseAlert.objectId,
            userId: parseAlert.userId,
            symbol: parseAlert.symbol,
            alertType: parseAlert.alertType,
            thresholdPrice: parseAlert.thresholdPrice,
            thresholdChangePercent: parseAlert.thresholdChangePercent,
            status: parseAlert.status,
            createdAt: parseAlert.createdAt,
            triggeredAt: parseAlert.triggeredAt,
            expiresAt: parseAlert.expiresAt,
            notificationSent: parseAlert.notificationSent,
            isEnabled: enabled,
            notes: parseAlert.notes
        )
        let modifiedAlert = PriceAlert(from: modifiedParseAlert)
        try await updateAlert(modifiedAlert)
    }

    func checkAlerts(for symbol: String, currentPrice: Double, previousPrice: Double?) async {
        let relevantAlerts = activeAlerts.filter { $0.symbol == symbol && $0.isEnabled && $0.status == .active }

        for alert in relevantAlerts {
            var shouldTrigger = false
            var triggeredStatus = PriceAlertStatus.triggered

            switch alert.alertType {
            case .above:
                if let threshold = alert.thresholdPrice, currentPrice >= threshold {
                    shouldTrigger = true
                }
            case .below:
                if let threshold = alert.thresholdPrice, currentPrice <= threshold {
                    shouldTrigger = true
                }
            case .change:
                if let previous = previousPrice, let threshold = alert.thresholdChangePercent {
                    let changePercent = abs((currentPrice - previous) / previous) * 100
                    if changePercent >= threshold {
                        shouldTrigger = true
                    }
                }
            }

            // Check expiration
            if let expiresAt = alert.expiresAt, expiresAt < Date() {
                shouldTrigger = false
                triggeredStatus = .expired
            }

            if shouldTrigger {
                await triggerAlert(alert)
            } else if triggeredStatus == .expired {
                await expireAlert(alert)
            }
        }
    }

    func loadAlerts() async throws {
        guard let userId = userService?.currentUser?.id else {
            throw AppError.authentication(.tokenExpired)
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        // Load from Parse Server
        if let apiClient = parseAPIClient {
            do {
                let parseAlerts: [ParsePriceAlert] = try await apiClient.fetchObjects(
                    className: "PriceAlert",
                    query: ["userId": userId],
                    include: nil,
                    orderBy: "-createdAt",
                    limit: 100
                )

                await MainActor.run {
                    allAlerts = parseAlerts.map { PriceAlert(from: $0) }
                    updateActiveAlerts()
                    isLoading = false
                }
            } catch {
                print("⚠️ Failed to load Price Alerts from Parse Server: \(error.localizedDescription)")
                await MainActor.run {
                    allAlerts = []
                    updateActiveAlerts()
                    isLoading = false
                }
            }
        } else {
            // Mock implementation
            await MainActor.run {
                allAlerts = []
                updateActiveAlerts()
                isLoading = false
            }
        }

        // Subscribe to Live Query updates
        await subscribeToLiveUpdates()
    }

    // MARK: - Private Methods

    private func setupNotificationObserver() {
        // Observe market data updates to check alerts
        NotificationCenter.default.publisher(for: .marketDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let symbol = userInfo["symbol"] as? String,
                      let price = userInfo["price"] as? Double else {
                    return
                }

                // Get previous price from cache
                let previousPrice = self.marketDataService?.getMarketPrice(for: symbol)

                // Check alerts for this symbol
                Task {
                    await self.checkAlerts(for: symbol, currentPrice: price, previousPrice: previousPrice)
                }
            }
            .store(in: &cancellables)
    }

    private func subscribeToLiveUpdates() async {
        guard let liveQueryClient = parseLiveQueryClient,
              let userId = userService?.currentUser?.id else {
            return
        }

        // Unsubscribe from previous subscription
        if let subscription = liveQuerySubscription {
            liveQueryClient.unsubscribe(subscription)
        }

        // Subscribe to PriceAlert updates for current user
        liveQuerySubscription = liveQueryClient.subscribe(
            className: "PriceAlert",
            query: ["userId": userId],
            onUpdate: { [weak self] (parseAlert: ParsePriceAlert) in
                Task { @MainActor in
                    self?.handleAlertUpdate(parseAlert)
                }
            },
            onDelete: { [weak self] objectId in
                Task { @MainActor in
                    self?.handleAlertDelete(objectId)
                }
            },
            onError: { error in
                print("⚠️ Live Query error for PriceAlert: \(error.localizedDescription)")
            }
        )
    }

    private func handleAlertUpdate(_ parseAlert: ParsePriceAlert) {
        let alert = PriceAlert(from: parseAlert)

        if let index = allAlerts.firstIndex(where: { $0.id == alert.id }) {
            allAlerts[index] = alert
        } else {
            allAlerts.append(alert)
        }

        updateActiveAlerts()
    }

    private func handleAlertDelete(_ objectId: String) {
        allAlerts.removeAll { $0.id == objectId }
        updateActiveAlerts()
    }

    private func updateActiveAlerts() {
        activeAlerts = allAlerts.filter { $0.status == .active && $0.isEnabled }
    }

    private func triggerAlert(_ alert: PriceAlert) async {
        let parseAlert = alert.toParsePriceAlert()
        let triggeredParseAlert = ParsePriceAlert(
            objectId: parseAlert.objectId,
            userId: parseAlert.userId,
            symbol: parseAlert.symbol,
            alertType: parseAlert.alertType,
            thresholdPrice: parseAlert.thresholdPrice,
            thresholdChangePercent: parseAlert.thresholdChangePercent,
            status: .triggered,
            createdAt: parseAlert.createdAt,
            triggeredAt: Date(),
            expiresAt: parseAlert.expiresAt,
            notificationSent: true,
            isEnabled: parseAlert.isEnabled,
            notes: parseAlert.notes
        )
        let triggeredAlert = PriceAlert(from: triggeredParseAlert)

        // Update in Parse Server
        if let apiClient = parseAPIClient, !triggeredAlert.id.isEmpty {
            do {
                let parseAlert = triggeredAlert.toParsePriceAlert()
                _ = try await apiClient.updateObject(
                    className: "PriceAlert",
                    objectId: triggeredAlert.id,
                    object: parseAlert
                )
            } catch {
                print("⚠️ Failed to update triggered Price Alert in Parse Server: \(error.localizedDescription)")
            }
        }

        // Update local cache
        await MainActor.run {
            if let index = allAlerts.firstIndex(where: { $0.id == alert.id }) {
                allAlerts[index] = triggeredAlert
                updateActiveAlerts()
            }
        }

        // Post notification
        NotificationCenter.default.post(
            name: .priceAlertTriggered,
            object: nil,
            userInfo: [
                "alert": triggeredAlert,
                "symbol": alert.symbol
            ]
        )

        print("🔔 Price Alert triggered: \(alert.symbol) - \(alert.alertType.rawValue)")
    }

    private func expireAlert(_ alert: PriceAlert) async {
        let parseAlert = alert.toParsePriceAlert()
        let expiredParseAlert = ParsePriceAlert(
            objectId: parseAlert.objectId,
            userId: parseAlert.userId,
            symbol: parseAlert.symbol,
            alertType: parseAlert.alertType,
            thresholdPrice: parseAlert.thresholdPrice,
            thresholdChangePercent: parseAlert.thresholdChangePercent,
            status: .expired,
            createdAt: parseAlert.createdAt,
            triggeredAt: parseAlert.triggeredAt,
            expiresAt: parseAlert.expiresAt,
            notificationSent: parseAlert.notificationSent,
            isEnabled: parseAlert.isEnabled,
            notes: parseAlert.notes
        )
        let expiredAlert = PriceAlert(from: expiredParseAlert)

        // Update in Parse Server
        if let apiClient = parseAPIClient, !expiredAlert.id.isEmpty {
            do {
                let parseAlert = expiredAlert.toParsePriceAlert()
                _ = try await apiClient.updateObject(
                    className: "PriceAlert",
                    objectId: expiredAlert.id,
                    object: parseAlert
                )
            } catch {
                print("⚠️ Failed to update expired Price Alert in Parse Server: \(error.localizedDescription)")
            }
        }

        // Update local cache
        await MainActor.run {
            if let index = allAlerts.firstIndex(where: { $0.id == alert.id }) {
                allAlerts[index] = expiredAlert
                updateActiveAlerts()
            }
        }
    }

    // MARK: - Backend Synchronization

    func syncToBackend() async {
        guard let apiClient = parseAPIClient,
              userService?.currentUser?.id != nil else {
            print("⚠️ ParseAPIClient or userId not available for Price Alert sync")
            return
        }

        print("📤 Syncing price alerts to backend...")

        // Sync all alerts that might not be synced (e.g., created offline)
        let alertsToSync = await MainActor.run { allAlerts }

        for alert in alertsToSync {
            // Check if alert exists on backend by trying to update it
            // If update fails, try to create it
            do {
                if !alert.id.isEmpty {
                    // Try to update existing alert
                    let parseAlert = alert.toParsePriceAlert()
                    _ = try await apiClient.updateObject(
                        className: "PriceAlert",
                        objectId: alert.id,
                        object: parseAlert
                    )
                } else {
                    // Create new alert if no ID
                    let parseAlert = alert.toParsePriceAlert()
                    let response = try await apiClient.createObject(
                        className: "PriceAlert",
                        object: parseAlert
                    )

                    // Update local alert with objectId
                    if let index = allAlerts.firstIndex(where: { $0.id == alert.id }) {
                        let updatedParseAlert = ParsePriceAlert(
                            objectId: response.objectId,
                            userId: parseAlert.userId,
                            symbol: parseAlert.symbol,
                            alertType: parseAlert.alertType,
                            thresholdPrice: parseAlert.thresholdPrice,
                            thresholdChangePercent: parseAlert.thresholdChangePercent,
                            status: parseAlert.status,
                            createdAt: parseAlert.createdAt,
                            triggeredAt: parseAlert.triggeredAt,
                            expiresAt: parseAlert.expiresAt,
                            notificationSent: parseAlert.notificationSent,
                            isEnabled: parseAlert.isEnabled,
                            notes: parseAlert.notes
                        )
                        await MainActor.run {
                            allAlerts[index] = PriceAlert(from: updatedParseAlert)
                            updateActiveAlerts()
                        }
                    }
                }
            } catch {
                print("⚠️ Failed to sync price alert \(alert.id): \(error.localizedDescription)")
            }
        }

        print("✅ Price alerts sync completed")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let priceAlertTriggered = Notification.Name("priceAlertTriggered")
}
