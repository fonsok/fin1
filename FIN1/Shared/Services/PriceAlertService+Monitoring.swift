import Combine
import Foundation

@MainActor
extension PriceAlertService {
    // MARK: - Monitoring

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

            if let expiresAt = alert.expiresAt, expiresAt < Date() {
                shouldTrigger = false
                triggeredStatus = .expired
            }

            if shouldTrigger {
                await self.triggerAlert(alert)
            } else if triggeredStatus == .expired {
                await self.expireAlert(alert)
            }
        }
    }

    func setupNotificationObserver() {
        NotificationCenter.default.publisher(for: .marketDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let symbol = userInfo["symbol"] as? String,
                      let price = userInfo["price"] as? Double else {
                    return
                }

                let previousPrice = self.marketDataService?.getMarketPrice(for: symbol)
                Task {
                    await self.checkAlerts(for: symbol, currentPrice: price, previousPrice: previousPrice)
                }
            }
            .store(in: &cancellables)
    }

    func subscribeToLiveUpdates() async {
        guard let liveQueryClient = parseLiveQueryClient,
              let userId = userService?.currentUser?.id else {
            return
        }

        if let subscription = liveQuerySubscription {
            liveQueryClient.unsubscribe(subscription)
        }

        liveQuerySubscription = liveQueryClient.subscribe(
            className: "PriceAlert",
            query: ["userId": userId],
            onUpdate: { [weak self] (parseAlert: ParsePriceAlert) in
                Task { @MainActor in self?.handleAlertUpdate(parseAlert) }
            },
            onDelete: { [weak self] objectId in
                Task { @MainActor in self?.handleAlertDelete(objectId) }
            },
            onError: { error in
                print("⚠️ Live Query error for PriceAlert: \(error.localizedDescription)")
            }
        )
    }

    func handleAlertUpdate(_ parseAlert: ParsePriceAlert) {
        let alert = PriceAlert(from: parseAlert)
        if let index = allAlerts.firstIndex(where: { $0.id == alert.id }) {
            allAlerts[index] = alert
        } else {
            allAlerts.append(alert)
        }
        self.updateActiveAlerts()
    }

    func handleAlertDelete(_ objectId: String) {
        allAlerts.removeAll { $0.id == objectId }
        self.updateActiveAlerts()
    }

    func updateActiveAlerts() {
        activeAlerts = allAlerts.filter { $0.status == .active && $0.isEnabled }
    }

    func triggerAlert(_ alert: PriceAlert) async {
        let parseAlert = alert.toParsePriceAlert()
        let triggeredAlert = PriceAlert(
            from: ParsePriceAlert(
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
        )

        if let apiClient = parseAPIClient, !triggeredAlert.id.isEmpty {
            do {
                _ = try await apiClient.updateObject(
                    className: "PriceAlert",
                    objectId: triggeredAlert.id,
                    object: triggeredAlert.toParsePriceAlert()
                )
            } catch {
                print("⚠️ Failed to update triggered Price Alert in Parse Server: \(error.localizedDescription)")
            }
        }

        if let index = allAlerts.firstIndex(where: { $0.id == alert.id }) {
            allAlerts[index] = triggeredAlert
            self.updateActiveAlerts()
        }

        NotificationCenter.default.post(
            name: .priceAlertTriggered,
            object: nil,
            userInfo: ["alert": triggeredAlert, "symbol": alert.symbol]
        )
        print("🔔 Price Alert triggered: \(alert.symbol) - \(alert.alertType.rawValue)")
    }

    func expireAlert(_ alert: PriceAlert) async {
        let parseAlert = alert.toParsePriceAlert()
        let expiredAlert = PriceAlert(
            from: ParsePriceAlert(
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
        )

        if let apiClient = parseAPIClient, !expiredAlert.id.isEmpty {
            do {
                _ = try await apiClient.updateObject(
                    className: "PriceAlert",
                    objectId: expiredAlert.id,
                    object: expiredAlert.toParsePriceAlert()
                )
            } catch {
                print("⚠️ Failed to update expired Price Alert in Parse Server: \(error.localizedDescription)")
            }
        }

        if let index = allAlerts.firstIndex(where: { $0.id == alert.id }) {
            allAlerts[index] = expiredAlert
            self.updateActiveAlerts()
        }
    }
}
