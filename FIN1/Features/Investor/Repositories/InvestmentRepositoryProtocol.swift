import Foundation
import Combine

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
    @Published var investments: [Investment] = []
    @Published var investmentBatches: [InvestmentBatch] = []
    @Published var investmentPools: [InvestmentPool] = []

    var investmentsPublisher: AnyPublisher<[Investment], Never> {
        $investments
            .handleEvents(receiveOutput: { investments in
                print("📡 InvestmentRepository.investmentsPublisher: Emitting \(investments.count) investments")
                if !investments.isEmpty {
                    for (index, inv) in investments.enumerated() {
                        print("   [\(index)] Investment \(inv.id): traderId='\(inv.traderId)', batchId=\(inv.batchId ?? "nil"), reservationStatus=\(inv.reservationStatus.rawValue)")
                    }
                }
            })
            .eraseToAnyPublisher()
    }

    /// Per-investor filtered publisher to prevent cross-user coupling in subscribers
    func investmentsPublisher(for investorId: String) -> AnyPublisher<[Investment], Never> {
        $investments
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
        guard !investments.contains(where: { $0.id == investment.id }) else { return }
        investments.append(investment)
    }

    /// Replaces an existing investment in-place (for backend status/financial sync)
    func updateInvestment(_ investment: Investment) {
        if let idx = investments.firstIndex(where: { $0.id == investment.id }) {
            investments[idx] = investment
        }
    }
}
