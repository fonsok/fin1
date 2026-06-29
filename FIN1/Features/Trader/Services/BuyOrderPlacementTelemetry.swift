import Foundation
import os

/// Structured placement observability (Console / Instruments — no emoji `print` in production).
enum BuyOrderPlacementTelemetry {

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.fin1.app",
        category: "BuyOrderPlacement"
    )

    static func placementStarted(intentId: String, symbol: String, quantity: Int, orderMode: OrderMode) {
        self.log.info(
            """
            placement_started intent=\(intentId, privacy: .public) \
            symbol=\(symbol, privacy: .public) quantity=\(quantity) \
            mode=\(orderMode.rawValue, privacy: .public)
            """
        )
    }

    static func placementFinished(
        intentId: String,
        durationMs: Int,
        outcome: String,
        errorCategory: String? = nil
    ) {
        if let errorCategory {
            self.log.info(
                """
                placement_finished intent=\(intentId, privacy: .public) \
                duration_ms=\(durationMs) outcome=\(outcome, privacy: .public) \
                error=\(errorCategory, privacy: .public)
                """
            )
        } else {
            self.log.info(
                """
                placement_finished intent=\(intentId, privacy: .public) \
                duration_ms=\(durationMs) outcome=\(outcome, privacy: .public)
                """
            )
        }
    }

    static func pairedBuyServerResponse(
        intentId: String,
        status: String,
        idempotentReplay: Bool,
        pairExecutionId: String?
    ) {
        let pair = pairExecutionId ?? "none"
        self.log.info(
            """
            paired_buy_response intent=\(intentId, privacy: .public) \
            status=\(status, privacy: .public) replay=\(idempotentReplay) \
            pair=\(pair, privacy: .public)
            """
        )
    }
}
