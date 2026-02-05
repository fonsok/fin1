import Foundation

// MARK: - Investments Data Processor

/// Handles investment data processing and transformation for InvestmentsViewModel
/// Separated to reduce main ViewModel file size and improve maintainability
final class InvestmentsDataProcessor {
    private let poolTradeParticipationService: any PoolTradeParticipationServiceProtocol

    init(poolTradeParticipationService: any PoolTradeParticipationServiceProtocol) {
        self.poolTradeParticipationService = poolTradeParticipationService
    }

    // MARK: - Investment-Level Data for Table Display

    /// Returns investment rows for ongoing investments
    /// Since each investment is now a first-class entity, we map investments directly to rows
    /// Sorted by: creation date (newest first), then trader name (A-Z), then investment number (ascending)
    func processOngoingInvestmentRows(from investments: [Investment]) -> [InvestmentRow] {
        var rows: [InvestmentRow] = []

        // Show all active investments except cancelled ones
        for investment in investments where investment.reservationStatus != .cancelled {
            let investmentStatus = mapInvestmentReservationStatus(investment.reservationStatus)
            let sequenceNumber = investment.sequenceNumber ?? 1

            // Calculate investment-level profit and return (actual values for completed investments)
            let investmentProfit = calculateInvestmentProfit(for: investment)
            let investmentReturn = calculateInvestmentReturn(for: investment, profit: investmentProfit)

            // Create an InvestmentReservation for backward compatibility with InvestmentRow
            let reservation = InvestmentReservation(
                id: investment.id,
                sequenceNumber: sequenceNumber,
                status: investment.reservationStatus,
                actualInvestmentId: nil,
                allocatedAmount: investment.amount,
                reservedAt: investment.createdAt,
                isLocked: investment.reservationStatus != .reserved
            )

            rows.append(InvestmentRow(
                id: investment.id,
                investmentId: investment.id,
                investmentNumber: investment.id.extractInvestmentNumber(),
                traderName: investment.traderName,
                sequenceNumber: sequenceNumber,
                status: investmentStatus,
                amount: investment.amount,
                profit: investmentProfit,
                returnPercentage: investmentReturn,
                reservation: reservation,
                investment: investment,
                docNumber: nil,
                invoiceNumber: nil
            ))
        }

        // Sort by: creation date (newest first), then trader name (A-Z), then investment number (ascending)
        return rows.sorted { first, second in
            // First: creation date (newest first)
            let firstDate = first.investment.createdAt
            let secondDate = second.investment.createdAt
            if firstDate != secondDate {
                return firstDate > secondDate
            }
            // Second: trader name (A-Z)
            if first.traderName != second.traderName {
                return first.traderName < second.traderName
            }
            // Third: investment number (ascending)
            // Extract numeric part from investment number for proper sorting
            let firstNumber = extractInvestmentNumber(from: first.investmentNumber)
            let secondNumber = extractInvestmentNumber(from: second.investmentNumber)
            return firstNumber < secondNumber
        }
    }

    /// Extracts numeric investment number from string (e.g., "INV-123" -> 123)
    func extractInvestmentNumber(from investmentNumber: String) -> Int {
        // Try to extract number from string like "INV-123" or just "123"
        let numbers = investmentNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(numbers) ?? 0
    }

    /// Total amount for ongoing investments
    func calculateTotalOngoingAmount(from rows: [InvestmentRow]) -> Double {
        rows.reduce(0) { $0 + $1.amount }
    }

    /// Total profit for ongoing investments (if available)
    func calculateTotalOngoingProfit(from rows: [InvestmentRow]) -> Double? {
        let profits = rows.compactMap { $0.profit }
        guard !profits.isEmpty else { return nil }
        return profits.reduce(0, +)
    }

    /// Total return percentage for ongoing investments (if available)
    func calculateTotalOngoingReturn(from rows: [InvestmentRow], totalAmount: Double) -> Double? {
        guard let totalProfit = calculateTotalOngoingProfit(from: rows), totalAmount > 0 else { return nil }
        return (totalProfit / totalAmount) * 100
    }

    // MARK: - Grouped Investment Data for View Display

    /// Returns investments grouped by trader name, with investments sorted by sequence number (ascending)
    /// This ensures Investment 1 appears first within each trader's group
    func groupOngoingInvestments(_ rows: [InvestmentRow]) -> [String: [InvestmentRow]] {
        let grouped = Dictionary(grouping: rows) { $0.traderName }

        // Sort investments within each trader group by sequence number (ascending)
        return grouped.mapValues { investments in
            investments.sorted { first, second in
                first.sequenceNumber < second.sequenceNumber
            }
        }
    }

    /// Returns trader names sorted alphabetically for display
    func sortedTraderNames(from grouped: [String: [InvestmentRow]]) -> [String] {
        grouped.keys.sorted()
    }

    // MARK: - Helper Methods

    private func mapInvestmentReservationStatus(_ status: InvestmentReservationStatus) -> InvestmentReservationStatusDisplay {
        switch status {
        case .reserved, .cancelled:
            // Status 1: Reserved/initial state - can be deleted
            return .reserved
        case .active, .closed, .executing:
            // Status 2: Active - trader started trade - cannot be deleted
            return .active
        case .completed:
            // Status 3: Completed - trader completed trade - cannot be deleted
            return .completed
        }
    }

    private func calculateInvestmentProfit(for investment: Investment) -> Double? {
        // For completed investments, get actual profit from PoolTradeParticipationService
        if investment.reservationStatus == .completed {
            let investmentProfit = poolTradeParticipationService.getAccumulatedProfit(forInvestmentReservationId: investment.id)
            return investmentProfit
        }
        // For non-completed investments, profit is not yet available
        return nil
    }

    private func calculateInvestmentReturn(for investment: Investment, profit: Double?) -> Double? {
        // Calculate return from profit if profit is available
        // Use gross profit (before commission) to match trader ROI calculation
        // NOTE: This is a simplified calculation for display purposes.
        // The authoritative calculation happens in InvestmentCompletionService.calculateInvestorTotals
        if let profit = profit {
            let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investment.id)
            // For completed investments, all trades should be fully sold, so allocatedAmount (securities value)
            // should match the sold securities value used in trader ROI calculation
            // Trader ROI uses: (profit) / (buyOrder.price * totalSoldQuantity) * 100
            // For completed investments: totalSoldQuantity = totalQuantity, so denominator matches
            let totalAllocatedAmount = participations.reduce(0.0) { $0 + $1.allocatedAmount }

            // Use investment.amount as fallback if no participations found (shouldn't happen for completed investments)
            let denominator = totalAllocatedAmount > 0 ? totalAllocatedAmount : investment.amount

            guard denominator > 0 else { return nil }

            // Net profit = Gross profit * (1 - commissionRate)
            // So: Gross profit = Net profit / (1 - commissionRate)
            let grossProfit = profit > 0 ?
                profit / (1.0 - CalculationConstants.FeeRates.traderCommissionRate) :
                profit
            return (grossProfit / denominator) * 100
        }
        // For non-completed investments, return is not yet available
        return nil
    }
}

