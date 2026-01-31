import Foundation
import Combine

// MARK: - Rounding Differences Service Protocol
protocol RoundingDifferencesServiceProtocol: AnyObject, ServiceLifecycle {
    var unreconciledDifferencesPublisher: AnyPublisher<[RoundingDifference], Never> { get }

    func trackRoundingDifference(
        transactionId: String,
        originalAmount: Double,
        roundedAmount: Double,
        transactionType: RoundingTransactionType
    ) async throws

    func getUnreconciledDifferences() async throws -> [RoundingDifference]
    func reconcileDifferences(_ differences: [RoundingDifference]) async throws
    func getRoundingDifferenceBalance() async throws -> Double
}
