import Combine
import Foundation

// MARK: - Rounding Differences Service
@MainActor
final class RoundingDifferencesService: RoundingDifferencesServiceProtocol, ObservableObject {
    @Published private var differences: [RoundingDifference] = []

    private let telemetryService: any TelemetryServiceProtocol

    private var cancellables = Set<AnyCancellable>()

    init(telemetryService: any TelemetryServiceProtocol) {
        self.telemetryService = telemetryService
    }

    // MARK: - Publisher
    var unreconciledDifferencesPublisher: AnyPublisher<[RoundingDifference], Never> {
        self.$differences
            .map { $0.filter { !$0.isReconciled } }
            .eraseToAnyPublisher()
    }

    // MARK: - API
    func trackRoundingDifference(
        transactionId: String,
        originalAmount: Double,
        roundedAmount: Double,
        transactionType: RoundingTransactionType
    ) async throws {
        let diff = roundedAmount - originalAmount
        guard abs(diff) >= 0.005 else { return } // track from half-cent upwards

        let model = RoundingDifference(
            id: UUID(),
            transactionId: transactionId,
            originalAmount: originalAmount,
            roundedAmount: roundedAmount,
            difference: diff,
            transactionType: transactionType,
            createdAt: Date(),
            isReconciled: false
        )

        self.differences.append(model)

        self.telemetryService.trackEvent(name: "rounding_difference_tracked", properties: [
            "transaction_type": transactionType.rawValue,
            "difference_amount": diff,
            "transaction_id": transactionId
        ])
    }

    func getUnreconciledDifferences() async throws -> [RoundingDifference] {
        return self.differences.filter { !$0.isReconciled }
    }

    func reconcileDifferences(_ recs: [RoundingDifference]) async throws {
        for rec in recs {
            if let idx = differences.firstIndex(where: { $0.id == rec.id }) {
                self.differences[idx].isReconciled = true
            }
        }

        let total = recs.reduce(0.0) { $0 + $1.difference }
        self.telemetryService.trackEvent(name: "rounding_differences_reconciled", properties: [
            "count": recs.count,
            "total_amount": total
        ])
    }

    func getRoundingDifferenceBalance() async throws -> Double {
        return self.differences.filter { !$0.isReconciled }.reduce(0.0) { $0 + $1.difference }
    }
}
