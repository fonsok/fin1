import Foundation
import Combine
@testable import FIN1

// MARK: - Mock Investment Service (Simplified)
/// Simplified mock using closure-based behavior instead of multiple configuration properties
class MockInvestmentService: InvestmentServiceProtocol {
    @Published var investments: [Investment] = []
    @Published var investmentPools: [InvestmentPool] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    // Publisher for investments (MVVM-friendly)
    var investmentsPublisher: AnyPublisher<[Investment], Never> {
        $investments.eraseToAnyPublisher()
    }
    func investmentsPublisher(for investorId: String) -> AnyPublisher<[Investment], Never> {
        $investments
            .map { list in list.filter { $0.investorId == investorId } }
            .eraseToAnyPublisher()
    }

    // MARK: - Behavior Closures (Simplified Approach)
    /// Closure to handle createInvestment - defaults to creating simple investment
    var createInvestmentHandler: ((User, MockTrader, Double, Int, String, PoolSelectionStrategy) async throws -> Void)?

    func createInvestment(
        investor: User,
        trader: MockTrader,
        amountPerPool: Double,
        numberOfPools: Int,
        specialization: String,
        poolSelection: PoolSelectionStrategy
    ) async throws {
        if let handler = createInvestmentHandler {
            try await handler(investor, trader, amountPerPool, numberOfPools, specialization, poolSelection)
        } else {
            // Default: create simple investment
            let investment = Investment(
                id: UUID().uuidString,
                investorId: investor.id,
                traderId: trader.id.uuidString,
                traderName: trader.name,
                amount: amountPerPool * Double(numberOfPools),
                currentValue: amountPerPool * Double(numberOfPools) * 1.05, // 5% gain
                date: Date(),
                status: .active,
                performance: 5.0,
                numberOfTrades: 0,
                numberOfPools: numberOfPools,
                createdAt: Date(),
                updatedAt: Date(),
                completedAt: nil,
                specialization: specialization,
                reservedPoolSlots: []
            )

            await MainActor.run {
                self.investments.append(investment)
            }
        }
    }

    func getInvestments(for investorId: String) -> [Investment] {
        return investments.filter { $0.investorId == investorId }
    }

    func getInvestments(forTrader traderId: String) -> [Investment] {
        return investments.filter { $0.traderId == traderId }
    }

    func getPools(forTrader traderId: String) -> [InvestmentPool] {
        return investmentPools.filter { $0.traderId == traderId }
    }

    func getGroupedInvestmentsByPool(forTrader traderId: String) -> [Int: [Investment]] {
        let traderInvestments = getInvestments(forTrader: traderId)
        return Dictionary(grouping: traderInvestments) { $0.numberOfPools }
    }

    // MARK: - Investment Status Management

    func markInvestmentAsActive(for traderId: String) async {
        await MainActor.run {
            let traderInvestments = investments.filter { $0.traderId == traderId && $0.status == .active }
            for investment in traderInvestments {
                if let reservedIndex = investment.reservedPoolSlots.firstIndex(where: { $0.status == .reserved }) {
                    var updatedReservations = investment.reservedPoolSlots
                    let oldReservation = updatedReservations[reservedIndex]
                    let updatedReservation = PoolReservation(
                        id: oldReservation.id,
                        poolNumber: oldReservation.poolNumber,
                        status: .active,
                        actualPoolId: oldReservation.actualPoolId,
                        allocatedAmount: oldReservation.allocatedAmount,
                        reservedAt: oldReservation.reservedAt,
                        isLocked: true
                    )
                    updatedReservations[reservedIndex] = updatedReservation
                    if let investmentIndex = investments.firstIndex(where: { $0.id == investment.id }) {
                        let updatedInvestment = Investment(
                            id: investment.id,
                            investorId: investment.investorId,
                            traderId: investment.traderId,
                            traderName: investment.traderName,
                            amount: investment.amount,
                            currentValue: investment.currentValue,
                            date: investment.date,
                            status: investment.status,
                            performance: investment.performance,
                            numberOfTrades: investment.numberOfTrades,
                            numberOfPools: investment.numberOfPools,
                            createdAt: investment.createdAt,
                            updatedAt: Date(),
                            completedAt: investment.completedAt,
                            specialization: investment.specialization,
                            reservedPoolSlots: updatedReservations
                        )
                        investments[investmentIndex] = updatedInvestment
                        break
                    }
                }
            }
        }
    }

    func markNextPoolAsActive(for investmentId: String) async {
        await MainActor.run {
            guard let idx = investments.firstIndex(where: { $0.id == investmentId }) else { return }
            var inv = investments[idx]
            if let reservedIndex = inv.reservedPoolSlots.firstIndex(where: { $0.status == .reserved }) {
                var slots = inv.reservedPoolSlots
                let old = slots[reservedIndex]
                let updated = PoolReservation(
                    id: old.id,
                    poolNumber: old.poolNumber,
                    status: .active,
                    actualPoolId: old.actualPoolId,
                    allocatedAmount: old.allocatedAmount,
                    reservedAt: old.reservedAt,
                    isLocked: true
                )
                slots[reservedIndex] = updated
                inv = Investment(
                    id: inv.id,
                    investorId: inv.investorId,
                    traderId: inv.traderId,
                    traderName: inv.traderName,
                    amount: inv.amount,
                    currentValue: inv.currentValue,
                    date: inv.date,
                    status: inv.status,
                    performance: inv.performance,
                    numberOfTrades: inv.numberOfTrades,
                    numberOfPools: inv.numberOfPools,
                    createdAt: inv.createdAt,
                    updatedAt: Date(),
                    completedAt: inv.completedAt,
                    specialization: inv.specialization,
                    reservedPoolSlots: slots
                )
                investments[idx] = inv
            }
        }
    }

    func markActivePoolAsCompleted(for investmentId: String) async {
        await MainActor.run {
            guard let idx = investments.firstIndex(where: { $0.id == investmentId }) else { return }
            var inv = investments[idx]
            if let activeIndex = inv.reservedPoolSlots.firstIndex(where: { $0.status == .active }) {
                var slots = inv.reservedPoolSlots
                let old = slots[activeIndex]
                let updated = PoolReservation(
                    id: old.id,
                    poolNumber: old.poolNumber,
                    status: .completed,
                    actualPoolId: old.actualPoolId,
                    allocatedAmount: old.allocatedAmount,
                    reservedAt: old.reservedAt,
                    isLocked: true
                )
                slots[activeIndex] = updated
                inv = Investment(
                    id: inv.id,
                    investorId: inv.investorId,
                    traderId: inv.traderId,
                    traderName: inv.traderName,
                    amount: inv.amount,
                    currentValue: inv.currentValue,
                    date: inv.date,
                    status: inv.status,
                    performance: inv.performance,
                    numberOfTrades: inv.numberOfTrades,
                    numberOfPools: inv.numberOfPools,
                    createdAt: inv.createdAt,
                    updatedAt: Date(),
                    completedAt: inv.completedAt,
                    specialization: inv.specialization,
                    reservedPoolSlots: slots
                )
                investments[idx] = inv
            }
        }
        await checkAndUpdateInvestmentCompletion()
    }

    func deleteInvestment(investmentId: String, reservationId: String) async {
        await MainActor.run {
            guard let idx = investments.firstIndex(where: { $0.id == investmentId }) else { return }
            var inv = investments[idx]
            inv.reservedPoolSlots.removeAll { $0.id == reservationId }
            inv = Investment(
                id: inv.id,
                investorId: inv.investorId,
                traderId: inv.traderId,
                traderName: inv.traderName,
                amount: inv.amount,
                currentValue: inv.currentValue,
                date: inv.date,
                status: inv.status,
                performance: inv.performance,
                numberOfTrades: inv.numberOfTrades,
                numberOfPools: inv.numberOfPools,
                createdAt: inv.createdAt,
                updatedAt: Date(),
                completedAt: inv.completedAt,
                specialization: inv.specialization,
                reservedPoolSlots: inv.reservedPoolSlots
            )
            investments[idx] = inv
        }
        await checkAndUpdateInvestmentCompletion()
    }

    func markInvestmentAsCompleted(for traderId: String) async {
        await MainActor.run {
            let traderInvestments = investments.filter { $0.traderId == traderId && $0.status == .active }
            for investment in traderInvestments {
                if let activeIndex = investment.reservedPoolSlots.firstIndex(where: { $0.status == .active }) {
                    var updatedReservations = investment.reservedPoolSlots
                    let oldReservation = updatedReservations[activeIndex]
                    let updatedReservation = PoolReservation(
                        id: oldReservation.id,
                        poolNumber: oldReservation.poolNumber,
                        status: .completed,
                        actualPoolId: oldReservation.actualPoolId,
                        allocatedAmount: oldReservation.allocatedAmount,
                        reservedAt: oldReservation.reservedAt,
                        isLocked: true
                    )
                    updatedReservations[activeIndex] = updatedReservation
                    if let investmentIndex = investments.firstIndex(where: { $0.id == investment.id }) {
                        let updatedInvestment = Investment(
                            id: investment.id,
                            investorId: investment.investorId,
                            traderId: investment.traderId,
                            traderName: investment.traderName,
                            amount: investment.amount,
                            currentValue: investment.currentValue,
                            date: investment.date,
                            status: investment.status,
                            performance: investment.performance,
                            numberOfTrades: investment.numberOfTrades,
                            numberOfPools: investment.numberOfPools,
                            createdAt: investment.createdAt,
                            updatedAt: Date(),
                            completedAt: investment.completedAt,
                            specialization: investment.specialization,
                            reservedPoolSlots: updatedReservations
                        )
                        investments[investmentIndex] = updatedInvestment
                        Task {
                            await self.checkAndUpdateInvestmentCompletion()
                        }
                        break
                    }
                }
            }
        }
    }

    func checkAndUpdateInvestmentCompletion() async {
        await MainActor.run {
            for index in investments.indices {
                let investment = investments[index]
                guard investment.status == .active else { continue }
                let hasPending = investment.reservedPoolSlots.contains { $0.status == .reserved || $0.status == .active || $0.status == .executing || $0.status == .closed }
                let hasCompleted = investment.reservedPoolSlots.contains { $0.status == .completed }
                if investment.allPoolsCompleted || !hasPending {
                    let updated = hasCompleted ? investment.markAsCompleted() : investment.markAsCancelled()
                    investments[index] = updated
                }
            }
        }
    }

    func updateInvestmentProfitsFromTrades() async {
        // No-op in mock
    }

    func selectNextInvestmentForTrader(_ traderId: String) async -> Investment? {
        return investments.first { $0.traderId == traderId && $0.status == .active && $0.reservedPoolSlots.contains { $0.status == .reserved } }
    }

    func start() {}
    func stop() {}

    func reset() {
        investments.removeAll()
        investmentPools.removeAll()
        isLoading = false
        errorMessage = nil
        showError = false
        // Reset all handlers
        createInvestmentHandler = nil
    }
}
