import Combine
@testable import FIN1
import Foundation

// MARK: - Mock Investment Service (Simplified)
/// Simplified mock using closure-based behavior instead of multiple configuration properties
final class MockInvestmentService: InvestmentServiceProtocol, @unchecked Sendable {
    @Published var investments: [Investment] = []
    @Published var investmentPools: [InvestmentPool] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    // Publisher for investments (MVVM-friendly)
    var investmentsPublisher: AnyPublisher<[Investment], Never> {
        self.$investments.eraseToAnyPublisher()
    }
    
    func investmentsPublisher(for investorId: String) -> AnyPublisher<[Investment], Never> {
        self.$investments
            .map { list in list.filter { $0.investorId == investorId } }
            .eraseToAnyPublisher()
    }

    // MARK: - Behavior Closures (Simplified Approach)
    /// Closure to handle createInvestment - defaults to creating simple investment
    var createInvestmentHandler: ((User, MockTrader, Double, Int, String, InvestmentSelectionStrategy) async throws -> Void)?

    func createInvestment(
        investor: User,
        trader: MockTrader,
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        specialization: String,
        poolSelection: InvestmentSelectionStrategy
    ) async throws {
        if let handler = createInvestmentHandler {
            try await handler(investor, trader, amountPerInvestment, numberOfInvestments, specialization, poolSelection)
        } else {
            // Default: create simple investment
            await MainActor.run {
                let investment = Investment(
                    id: UUID().uuidString,
                    batchId: nil,
                    investorId: investor.id,
                    investorName: investor.displayName,
                    traderId: trader.id.uuidString,
                    traderName: trader.name,
                    amount: amountPerInvestment * Double(numberOfInvestments),
                    currentValue: amountPerInvestment * Double(numberOfInvestments) * 1.05, // 5% gain
                    date: Date(),
                    status: .active,
                    performance: 5.0,
                    numberOfTrades: 0,
                    sequenceNumber: 1,
                    createdAt: Date(),
                    updatedAt: Date(),
                    completedAt: nil,
                    specialization: specialization,
                    reservationStatus: .active
                )

                self.investments.append(investment)
            }
        }
    }

    func getInvestments(for investorId: String) -> [Investment] {
        return self.investments.filter { $0.investorId == investorId }
    }

    func getInvestments(forTrader traderId: String) -> [Investment] {
        return self.investments.filter { $0.traderId == traderId }
    }

    func getInvestmentPools(forTrader traderId: String) -> [InvestmentPool] {
        return self.investmentPools.filter { $0.traderId == traderId }
    }

    func getGroupedInvestmentsBySequence(forTrader traderId: String) -> [Int: [Investment]] {
        let traderInvestments = self.getInvestments(forTrader: traderId)
        return Dictionary(grouping: traderInvestments) { $0.sequenceNumber ?? 0 }
    }

    func selectNextInvestmentForTrader(_ traderId: String) async -> Investment? {
        return self.investments.first { $0.traderId == traderId && $0.status == .active && $0.reservationStatus == .reserved }
    }

    func selectNextInvestmentForInvestor(_ investorId: String, traderId: String) async -> Investment? {
        return self.investments.first { 
            $0.investorId == investorId && 
                $0.traderId == traderId && 
                $0.status == .active && 
                $0.reservationStatus == .reserved 
        }
    }

    // MARK: - Investment Status Management

    func markInvestmentAsActive(for traderId: String) async {
        await MainActor.run {
            for index in self.investments.indices {
                if self.investments[index].traderId == traderId && self.investments[index].status == .active {
                    let investment = self.investments[index]
                    if investment.reservationStatus == .reserved {
                        // Update to active - simplified, as Investment is a struct
                        let updated = Investment(
                            id: investment.id,
                            batchId: investment.batchId,
                            investorId: investment.investorId,
                            investorName: investment.investorName,
                            traderId: investment.traderId,
                            traderName: investment.traderName,
                            amount: investment.amount,
                            currentValue: investment.currentValue,
                            date: investment.date,
                            status: investment.status,
                            performance: investment.performance,
                            numberOfTrades: investment.numberOfTrades,
                            sequenceNumber: investment.sequenceNumber,
                            createdAt: investment.createdAt,
                            updatedAt: Date(),
                            completedAt: investment.completedAt,
                            specialization: investment.specialization,
                            reservationStatus: .active
                        )
                        self.investments[index] = updated
                        break
                    }
                }
            }
        }
    }

    func markInvestmentAsCompleted(for traderId: String) async {
        await MainActor.run {
            for index in self.investments.indices {
                if self.investments[index].traderId == traderId && self.investments[index].status == .active {
                    let investment = self.investments[index]
                    if investment.reservationStatus == .active {
                        let updated = investment.markAsCompleted()
                        self.investments[index] = updated
                        break
                    }
                }
            }
        }
        await self.checkAndUpdateInvestmentCompletion()
    }

    func markNextInvestmentAsActive(for investmentId: String) async {
        await MainActor.run {
            guard let idx = investments.firstIndex(where: { $0.id == investmentId }) else { return }
            let inv = self.investments[idx]
            if inv.reservationStatus == .reserved {
                let updated = Investment(
                    id: inv.id,
                    batchId: inv.batchId,
                    investorId: inv.investorId,
                    investorName: inv.investorName,
                    traderId: inv.traderId,
                    traderName: inv.traderName,
                    amount: inv.amount,
                    currentValue: inv.currentValue,
                    date: inv.date,
                    status: inv.status,
                    performance: inv.performance,
                    numberOfTrades: inv.numberOfTrades,
                    sequenceNumber: inv.sequenceNumber,
                    createdAt: inv.createdAt,
                    updatedAt: Date(),
                    completedAt: inv.completedAt,
                    specialization: inv.specialization,
                    reservationStatus: .active
                )
                self.investments[idx] = updated
            }
        }
    }

    func markActiveInvestmentAsCompleted(for investmentId: String) async {
        await MainActor.run {
            guard let idx = investments.firstIndex(where: { $0.id == investmentId }) else { return }
            let inv = self.investments[idx]
            if inv.reservationStatus == .active {
                let updated = inv.markAsCompleted()
                self.investments[idx] = updated
            }
        }
        await self.checkAndUpdateInvestmentCompletion()
    }

    func deleteInvestment(investmentId: String, reservationId: String) async {
        await MainActor.run {
            // Simplified: just remove the investment if it matches
            self.investments.removeAll { $0.id == investmentId }
        }
        await self.checkAndUpdateInvestmentCompletion()
    }

    func checkAndUpdateInvestmentCompletion() async {
        await MainActor.run {
            for index in self.investments.indices {
                let investment = self.investments[index]
                guard investment.status == .active else { continue }
                if investment.reservationStatus == .completed {
                    let updated = investment.markAsCompleted()
                    self.investments[index] = updated
                }
            }
        }
    }

    func updateInvestmentProfitsFromTrades() async {
        // No-op in mock
    }

    func configureCalculationServices(
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)?,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)?
    ) {
        // No-op in mock
    }

    func syncToBackend() async {
        // Mock: no-op
    }

    func fetchFromBackend(for investorId: String) async {
        // Mock: no-op
    }

    func start() {}
    func stop() {}

    func reset() {
        self.investments.removeAll()
        self.investmentPools.removeAll()
        self.isLoading = false
        self.errorMessage = nil
        self.showError = false
        // Reset all handlers
        self.createInvestmentHandler = nil
    }
}
