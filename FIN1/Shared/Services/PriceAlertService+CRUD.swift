import Foundation

@MainActor
extension PriceAlertService {
    // MARK: - CRUD

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

        if let apiClient = parseAPIClient {
            do {
                let response = try await apiClient.createObject(className: "PriceAlert", object: parseAlert)
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
                allAlerts.append(alert)
                updateActiveAlerts()
                return alert
            } catch {
                print("⚠️ Failed to create Price Alert in Parse Server: \(error.localizedDescription)")
            }
        }

        let alert = PriceAlert(from: parseAlert)
        allAlerts.append(alert)
        updateActiveAlerts()
        return alert
    }

    func updateAlert(_ alert: PriceAlert) async throws {
        guard let userId = userService?.currentUser?.id, userId == alert.userId else {
            throw AppError.authentication(.tokenExpired)
        }

        if let apiClient = parseAPIClient, !alert.id.isEmpty {
            do {
                _ = try await apiClient.updateObject(
                    className: "PriceAlert",
                    objectId: alert.id,
                    object: alert.toParsePriceAlert()
                )
            } catch {
                print("⚠️ Failed to update Price Alert in Parse Server: \(error.localizedDescription)")
            }
        }

        if let index = allAlerts.firstIndex(where: { $0.id == alert.id }) {
            allAlerts[index] = alert
            updateActiveAlerts()
        }
    }

    func deleteAlert(_ alertId: String) async throws {
        guard userService?.currentUser?.id != nil else {
            throw AppError.authentication(.tokenExpired)
        }

        if let apiClient = parseAPIClient {
            do {
                try await apiClient.deleteObject(className: "PriceAlert", objectId: alertId)
            } catch {
                print("⚠️ Failed to delete Price Alert from Parse Server: \(error.localizedDescription)")
            }
        }

        allAlerts.removeAll { $0.id == alertId }
        updateActiveAlerts()
    }

    func setAlertEnabled(_ alertId: String, enabled: Bool) async throws {
        guard let alert = allAlerts.first(where: { $0.id == alertId }) else {
            throw AppError.service(.dataNotFound)
        }

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
        try await updateAlert(PriceAlert(from: modifiedParseAlert))
    }

    func loadAlerts() async throws {
        guard let userId = userService?.currentUser?.id else {
            throw AppError.authentication(.tokenExpired)
        }

        isLoading = true
        errorMessage = nil

        if let apiClient = parseAPIClient {
            do {
                let parseAlerts: [ParsePriceAlert] = try await apiClient.fetchObjects(
                    className: "PriceAlert",
                    query: ["userId": userId],
                    include: nil,
                    orderBy: "-createdAt",
                    limit: 100
                )
                allAlerts = parseAlerts.map { PriceAlert(from: $0) }
                updateActiveAlerts()
                isLoading = false
            } catch {
                print("⚠️ Failed to load Price Alerts from Parse Server: \(error.localizedDescription)")
                allAlerts = []
                updateActiveAlerts()
                isLoading = false
            }
        } else {
            allAlerts = []
            updateActiveAlerts()
            isLoading = false
        }

        await subscribeToLiveUpdates()
    }
}
