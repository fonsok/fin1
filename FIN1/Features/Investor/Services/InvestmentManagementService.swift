import Foundation
import Combine

// MARK: - Investment Management Service Implementation
/// Handles investment status management and round-robin allocation
/// Note: Each investment is a first-class entity, so we work directly with investments
final class InvestmentManagementService: InvestmentManagementServiceProtocol {

    var investmentPools: [InvestmentPool] = []

    // Round-robin allocation queues per traderId
    private var allocationQueues: [String: [String]] = [:]

    // Round-robin allocation queues per investor (for per-investor selection)
    // Key format: "traderId:investorId" to maintain separate queues per investor per trader
    private var investorAllocationQueues: [String: [String]] = [:]

    init() {}

    // MARK: - ServiceLifecycle

    func start() { /* preload if needed */ }

    func stop() { /* noop */ }

    func reset() {
        investmentPools.removeAll()
        allocationQueues.removeAll()
        investorAllocationQueues.removeAll()
    }

    // MARK: - Investment Reservation Creation (Deprecated - kept for compatibility)
    /// DEPRECATED: Investment reservations are no longer used. Each investment is now a first-class entity.
    /// This method is kept for backward compatibility but should not be used.
    func createInvestmentReservations(for investment: Investment, trader: MockTrader) -> [InvestmentReservation] {
        // Since each investment is a first-class entity, this method is no longer needed
        // Return empty array for compatibility
        return []
    }

    /// Creates a new investment pool for a trader
    func createNewInvestmentPool(for traderId: String, sequenceNumber: Int, amountPerInvestment: Double) -> InvestmentPool {
        return InvestmentPool(
            id: UUID().uuidString,
            traderId: traderId,
            poolNumber: sequenceNumber, // InvestmentPool uses poolNumber for trader dashboard compatibility
            status: .active,
            currentBalance: amountPerInvestment,
            totalInvested: amountPerInvestment,
            numberOfInvestors: 1,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil
        )
    }

    // MARK: - Investment Status Management
    /// Now works directly with individual investments (each investment is a first-class entity)

    /// Marks the first reserved investment as active for a trader
    func markInvestmentAsActive(for traderId: String, in investments: [Investment]) -> Investment? {
        // Find all active investments for this trader with reserved status
        let traderInvestments = investments.filter {
            $0.traderId == traderId &&
            $0.status == .active &&
            $0.reservationStatus == .reserved
        }
        .sorted(by: { $0.createdAt < $1.createdAt }) // Oldest first for fairness

        // Mark the first reserved investment as active
        if let investment = traderInvestments.first {
            return investment.markInvestmentAsActive()
        }
        return nil
    }

    /// Marks the first active investment as completed for a trader
    func markInvestmentAsCompleted(for traderId: String, in investments: [Investment]) -> (Investment, InvestmentReservation)? {
        // Find all active investments for this trader with active reservation status
        let traderInvestments = investments.filter {
            $0.traderId == traderId &&
            $0.status == .active &&
            ($0.reservationStatus == .active || $0.reservationStatus == .executing || $0.reservationStatus == .closed)
        }
        .sorted(by: { $0.createdAt < $1.createdAt }) // Oldest first

        // Mark the first active investment as completed
        if let investment = traderInvestments.first {
            let updatedInvestment = investment.markInvestmentAsCompleted()

            // Create an InvestmentReservation for backward compatibility (used in cash distribution)
            let reservation = InvestmentReservation(
                id: investment.id, // Use investment ID as reservation ID
                sequenceNumber: investment.sequenceNumber ?? 1,
                status: .completed,
                actualInvestmentId: nil,
                allocatedAmount: investment.amount,
                reservedAt: investment.createdAt,
                isLocked: true
            )

            return (updatedInvestment, reservation)
        }
        return nil
    }

    /// Marks the next reserved investment as active for a specific investment
    func markNextInvestmentAsActive(for investmentId: String, in investments: [Investment]) -> Investment? {
        guard let investment = investments.first(where: { $0.id == investmentId }) else {
            return nil
        }

        // If this investment is reserved, mark it as active
        if investment.reservationStatus == .reserved {
            return investment.markInvestmentAsActive()
        }
        return nil
    }

    /// Marks the active investment as completed for a specific investment
    func markActiveInvestmentAsCompleted(for investmentId: String, in investments: [Investment]) -> (Investment, InvestmentReservation)? {
        guard let investment = investments.first(where: { $0.id == investmentId }) else {
            return nil
        }

        // If this investment is active, mark it as completed
        if investment.reservationStatus == .active || investment.reservationStatus == .executing || investment.reservationStatus == .closed {
            let updatedInvestment = investment.markInvestmentAsCompleted()

            // Create an InvestmentReservation for backward compatibility
            let reservation = InvestmentReservation(
                id: investment.id,
                sequenceNumber: investment.sequenceNumber ?? 1,
                status: .completed,
                actualInvestmentId: nil,
                allocatedAmount: investment.amount,
                reservedAt: investment.createdAt,
                isLocked: true
            )

            return (updatedInvestment, reservation)
        }
        return nil
    }

    /// Deletes a reserved investment - now just returns nil since deletion is handled elsewhere
    /// This method is kept for compatibility but investments should be deleted directly
    func deleteInvestment(investmentId: String, reservationId: String, in investments: [Investment]) -> Investment? {
        // Since each investment is now a first-class entity, deletion is handled by removing the investment
        // This method is kept for compatibility but should not be used
        return nil
    }

    // MARK: - Round-Robin Allocation

    /// Select next eligible investment for a trader using fair round-robin allocation
    func selectNextInvestmentForTrader(_ traderId: String, in investments: [Investment]) -> Investment? {
        // Build or refresh queue if missing/empty
        if allocationQueues[traderId] == nil || allocationQueues[traderId]?.isEmpty == true {
            let orderedIds = investments
                .filter {
                    $0.traderId == traderId &&
                    $0.status == .active &&
                    $0.reservationStatus == .reserved
                }
                .sorted(by: { $0.createdAt < $1.createdAt })
                .map { $0.id }
            allocationQueues[traderId] = orderedIds
        }

        guard var queue = allocationQueues[traderId], !queue.isEmpty else {
            return nil
        }

        var attempts = 0
        while attempts < queue.count, !queue.isEmpty {
            let candidateId = queue.removeFirst()
            defer { attempts += 1 }

            if let inv = investments.first(where: { $0.id == candidateId }),
               inv.status == .active,
               inv.reservationStatus == .reserved {
                // Rotate candidate to end for round-robin fairness
                queue.append(candidateId)
                allocationQueues[traderId] = queue
                return inv
            }
            // Skip depleted/invalid candidate; do not re-append
        }

        // Cleanup any invalid entries
        allocationQueues[traderId] = queue.filter { id in
            if let inv = investments.first(where: { $0.id == id }) {
                return inv.status == .active && inv.reservationStatus == .reserved
            }
            return false
        }
        return nil
    }

    /// Select next eligible investment for a specific investor using fair round-robin allocation
    /// This ensures each investor gets fair representation (one investment per investor per trade)
    func selectNextInvestmentForInvestor(_ investorId: String, traderId: String, in investments: [Investment]) -> Investment? {
        // Create a composite key for this investor-trader combination
        let queueKey = "\(traderId):\(investorId)"

        // Build or refresh queue if missing/empty
        if investorAllocationQueues[queueKey] == nil || investorAllocationQueues[queueKey]?.isEmpty == true {
            let orderedIds = investments
                .filter {
                    $0.investorId == investorId &&
                    $0.traderId == traderId &&
                    $0.status == .active &&
                    $0.reservationStatus == .reserved
                }
                .sorted(by: { $0.createdAt < $1.createdAt })
                .map { $0.id }
            investorAllocationQueues[queueKey] = orderedIds
        }

        guard var queue = investorAllocationQueues[queueKey], !queue.isEmpty else {
            return nil
        }

        var attempts = 0
        while attempts < queue.count, !queue.isEmpty {
            let candidateId = queue.removeFirst()
            defer { attempts += 1 }

            if let inv = investments.first(where: { $0.id == candidateId }),
               inv.investorId == investorId,
               inv.traderId == traderId,
               inv.status == .active,
               inv.reservationStatus == .reserved {
                // Rotate candidate to end for round-robin fairness
                queue.append(candidateId)
                investorAllocationQueues[queueKey] = queue
                return inv
            }
            // Skip depleted/invalid candidate; do not re-append
        }

        // Cleanup any invalid entries
        investorAllocationQueues[queueKey] = queue.filter { id in
            if let inv = investments.first(where: { $0.id == id }) {
                return inv.investorId == investorId &&
                       inv.traderId == traderId &&
                       inv.status == .active &&
                       inv.reservationStatus == .reserved
            }
            return false
        }
        return nil
    }

    // MARK: - Investment Pool Queries

    /// Gets all investment pools for a specific trader
    func getInvestmentPools(forTrader traderId: String) -> [InvestmentPool] {
        return investmentPools.filter { $0.traderId == traderId }
    }

    /// Groups investments by sequence number for a specific trader
    func getGroupedInvestmentsBySequence(forTrader traderId: String, in investments: [Investment]) -> [Int: [Investment]] {
        let traderInvestments = investments.filter { $0.traderId == traderId }
        var groupedInvestments: [Int: [Investment]] = [:]

        for investment in traderInvestments {
            let sequenceNumber = investment.sequenceNumber ?? 1
            if groupedInvestments[sequenceNumber] == nil {
                groupedInvestments[sequenceNumber] = []
            }
            groupedInvestments[sequenceNumber]?.append(investment)
        }

        return groupedInvestments
    }
}
