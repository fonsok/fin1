import XCTest
@testable import FIN1

final class RoundingDifferencesViewModelTests: XCTestCase {
    func testLoadPopulatesState() async throws {
        // Given
        let telemetry = MockTelemetryService()
        let service = RoundingDifferencesService(telemetryService: telemetry)
        try await service.trackRoundingDifference(
            transactionId: "tx-3",
            originalAmount: 5.555,
            roundedAmount: 5.56,
            transactionType: .tradeProfit
        )
        let vm = await RoundingDifferencesViewModel(roundingService: service, telemetryService: telemetry)

        // When
        await vm.load()

        // Then
        await MainActor.run {
            XCTAssertEqual(vm.unreconciledDifferences.count, 1)
            XCTAssertEqual(vm.totalRoundingBalance, 0.005, accuracy: 0.0001)
            XCTAssertNil(vm.errorMessage)
        }
    }

    func testReconcileAllClearsItems() async throws {
        // Given
        let telemetry = MockTelemetryService()
        let service = RoundingDifferencesService(telemetryService: telemetry)
        try await service.trackRoundingDifference(
            transactionId: "tx-4",
            originalAmount: 9.999,
            roundedAmount: 10.00,
            transactionType: .invoiceTotal
        )
        let vm = await RoundingDifferencesViewModel(roundingService: service, telemetryService: telemetry)
        await vm.load()
        await MainActor.run {
            XCTAssertEqual(vm.unreconciledDifferences.count, 1)
        }

        // When
        await vm.reconcileAll()

        // Then
        await MainActor.run {
            XCTAssertTrue(vm.unreconciledDifferences.isEmpty)
        }
        XCTAssertEqual(telemetry.trackedEvents.last?.0, "rounding_reconcile_all")
    }
}
