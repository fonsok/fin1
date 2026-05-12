import Foundation

@MainActor
extension TradesOverviewViewModel {
    func clearError() {
        errorMessage = nil
        showError = false
    }

    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }

    func showError(_ error: AppError) {
        errorMessage = error.errorDescription ?? "An error occurred"
        showError = true
    }

    func handleError(_ error: Error) {
        let appError = error.toAppError()
        errorMessage = appError.errorDescription ?? "An error occurred"
        showError = true
    }

    func subscribeToLiveUpdates() async {
        guard let liveQueryClient = parseLiveQueryClient,
              let traderId = currentTraderId else {
            return
        }

        let orderSubscription = liveQueryClient.subscribe(
            className: "Order",
            query: ["traderId": traderId],
            onUpdate: { [weak self] (_: ParseOrder) in
                Task { @MainActor [weak self] in
                    await self?.rebuildTrades()
                }
            },
            onDelete: { [weak self] (_: String) in
                Task { @MainActor [weak self] in
                    await self?.rebuildTrades()
                }
            },
            onError: { error in
                print("⚠️ Live Query error for Order: \(error.localizedDescription)")
            }
        )
        liveQuerySubscriptions.append(orderSubscription)

        let tradeSubscription = liveQueryClient.subscribe(
            className: "Trade",
            query: ["traderId": traderId],
            onUpdate: { [weak self] (_: ParseTrade) in
                Task { @MainActor [weak self] in
                    await self?.rebuildTrades()
                }
            },
            onDelete: { [weak self] (_: String) in
                Task { @MainActor [weak self] in
                    await self?.rebuildTrades()
                }
            },
            onError: { error in
                print("⚠️ Live Query error for Trade: \(error.localizedDescription)")
            }
        )
        liveQuerySubscriptions.append(tradeSubscription)
    }
}
