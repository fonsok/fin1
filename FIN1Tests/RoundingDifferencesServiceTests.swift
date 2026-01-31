import XCTest
@testable import FIN1

final class RoundingDifferencesServiceTests: XCTestCase {
    func testTrackRoundingDifference_appendsAndPublishes() async throws {
        // Given
        let telemetry = MockTelemetryService()
        let service = RoundingDifferencesService(telemetryService: telemetry)

        // When
        try await service.trackRoundingDifference(
            transactionId: "tx-1",
            originalAmount: 83.3325,
            roundedAmount: 83.33,
            transactionType: .taxCalculation
        )

        let items = try await service.getUnreconciledDifferences()

        // Then
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.transactionId, "tx-1")
        XCTAssertEqual(items.first?.transactionType, .taxCalculation)
        XCTAssertEqual(items.first?.difference ?? 0, -0.0025, accuracy: 0.0001)
        XCTAssertEqual(telemetry.trackedEvents.first?.0, "rounding_difference_tracked")
    }

    func testReconcileDifferences_marksAsReconciled_andTracksEvent() async throws {
        // Given
        let telemetry = MockTelemetryService()
        let service = RoundingDifferencesService(telemetryService: telemetry)
        try await service.trackRoundingDifference(
            transactionId: "tx-2",
            originalAmount: 10.004,
            roundedAmount: 10.00,
            transactionType: .invoiceTotal
        )

        var items = try await service.getUnreconciledDifferences()
        XCTAssertEqual(items.count, 1)

        // When
        try await service.reconcileDifferences(items)

        // Then
        items = try await service.getUnreconciledDifferences()
        XCTAssertTrue(items.isEmpty)
        XCTAssertEqual(telemetry.trackedEvents.last?.0, "rounding_differences_reconciled")
    }

    func testGetRoundingDifferenceBalance_sumsUnreconciled() async throws {
        // Given
        let telemetry = MockTelemetryService()
        let service = RoundingDifferencesService(telemetryService: telemetry)
        try await service.trackRoundingDifference(
            transactionId: "tx-a",
            originalAmount: 1.234,
            roundedAmount: 1.23,
            transactionType: .feeCalculation
        )
        try await service.trackRoundingDifference(
            transactionId: "tx-b",
            originalAmount: 2.345,
            roundedAmount: 2.35,
            transactionType: .feeCalculation
        )

        // When
        let balance = try await service.getRoundingDifferenceBalance()

        // Then
        XCTAssertEqual(balance, (-0.004) + 0.005, accuracy: 0.0001)
    }
}
