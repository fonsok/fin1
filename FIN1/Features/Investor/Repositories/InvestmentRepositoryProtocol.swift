import Combine
import Foundation
import os

// MARK: - Investment Repository Protocol
/// Owns mutable state for investor investments, batches, and pools.
protocol InvestmentRepositoryProtocol: ObservableObject {
    var investments: [Investment] { get set }
    var investmentBatches: [InvestmentBatch] { get set }
    var investmentPools: [InvestmentPool] { get set }

    var investmentsPublisher: AnyPublisher<[Investment], Never> { get }
    func investmentsPublisher(for investorId: String) -> AnyPublisher<[Investment], Never>

    /// Adds an investment (used for backend merge)
    func addInvestment(_ investment: Investment)

    /// Replaces an existing investment in-place (used for backend status sync)
    func updateInvestment(_ investment: Investment)
}

// MARK: - Investment Repository Implementation
final class InvestmentRepository: InvestmentRepositoryProtocol {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FIN1",
        category: "InvestmentRepository"
    )

    @Published var investments: [Investment] = []
    @Published var investmentBatches: [InvestmentBatch] = []
    @Published var investmentPools: [InvestmentPool] = []

    var investmentsPublisher: AnyPublisher<[Investment], Never> {
        self.$investments
            .handleEvents(receiveOutput: { investments in
                Self.log.debug("investmentsPublisher emit count=\(investments.count)")
            })
            .eraseToAnyPublisher()
    }

    /// Per-investor filtered publisher to prevent cross-user coupling in subscribers
    func investmentsPublisher(for investorId: String) -> AnyPublisher<[Investment], Never> {
        self.$investments
            .map { all in
                all.filter { $0.investorId == investorId }
            }
            .removeDuplicates(by: { lhs, rhs in
                // Shallow equality by ids and updatedAt to limit unnecessary UI churn
                guard lhs.count == rhs.count else { return false }
                return zip(lhs, rhs).allSatisfy { $0.id == $1.id && $0.updatedAt == $1.updatedAt }
            })
            .eraseToAnyPublisher()
    }

    /// Adds an investment if not already present (idempotent)
    func addInvestment(_ investment: Investment) {
        guard !self.investments.contains(where: { $0.id == investment.id }) else { return }
        self.investments.append(investment)
    }

    /// Replaces an existing investment in-place (for backend status/financial sync)
    func updateInvestment(_ investment: Investment) {
        if let idx = investments.firstIndex(where: { $0.id == investment.id }) {
            self.investments[idx] = investment
        }
    }
}
