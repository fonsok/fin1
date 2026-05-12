import Foundation

@MainActor
extension PriceAlertService {
    // MARK: - Backend Synchronization

    func syncToBackend() async {
        guard let apiClient = parseAPIClient, userService?.currentUser?.id != nil else {
            print("⚠️ ParseAPIClient or userId not available for Price Alert sync")
            return
        }

        print("📤 Syncing price alerts to backend...")
        let alertsToSync = allAlerts

        for alert in alertsToSync {
            do {
                if !alert.id.isEmpty {
                    _ = try await apiClient.updateObject(
                        className: "PriceAlert",
                        objectId: alert.id,
                        object: alert.toParsePriceAlert()
                    )
                } else {
                    let parseAlert = alert.toParsePriceAlert()
                    let response = try await apiClient.createObject(className: "PriceAlert", object: parseAlert)

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
                        allAlerts[index] = PriceAlert(from: updatedParseAlert)
                        updateActiveAlerts()
                    }
                }
            } catch {
                print("⚠️ Failed to sync price alert \(alert.id): \(error.localizedDescription)")
            }
        }

        print("✅ Price alerts sync completed")
    }
}
