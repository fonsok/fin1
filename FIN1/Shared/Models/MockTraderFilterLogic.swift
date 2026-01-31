import Foundation

// MARK: - Mock Trader Filter Logic
/// Extension containing all filter matching logic for MockTrader
extension MockTrader {

    // MARK: - Filter Methods
    func matchesFilterCriteria(_ criteria: IndividualFilterCriteria) -> Bool {
        switch criteria.type {
        case .returnRate:
            if let option = criteria.returnPercentageOption {
                return matchesReturnRateFilter(option)
            }
            return false
        case .recentSuccessfulTrades:
            if let option = criteria.successRateOption {
                return matchesRecentSuccessfulTradesFilter(option)
            }
            return false
        case .highestReturn:
            if let option = criteria.successRateOption {
                return matchesHighestReturnFilter(option)
            }
            return false
        case .numberOfTrades:
            if let option = criteria.numberOfTradesOption {
                return matchesNumberOfTradesFilter(option)
            }
            return false
        case .timeRange:
            if let option = criteria.successRateOption {
                return matchesTimeRangeFilter(option)
            }
            return false
        }
    }

    func matchesFilterCombination(_ combination: FilterCombination) -> Bool {
        return combination.filters.allSatisfy { matchesFilterCriteria($0) }
    }

    // MARK: - Individual Filter Matching
    private func matchesReturnRateFilter(_ option: ReturnPercentageOption) -> Bool {
        guard let minimumPercentage = option.minimumPercentage else {
            return false
        }

        // Calculate average ROI (Return on Investment) per trade
        // Ø-Return per Trade = Average ROI across all trades
        guard !recentTrades.isEmpty else { return false }

        // Calculate average ROI: average of (preTaxProfit / investmentCost) * 100 for each trade
        let totalROI = recentTrades.reduce(0.0) { $0 + $1.roi }
        let averageROI = totalROI / Double(recentTrades.count)

        return averageROI >= minimumPercentage
    }

    private func matchesRecentSuccessfulTradesFilter(_ option: FilterSuccessRateOption) -> Bool {
        guard let requiredCount = option.requiredSuccessCount,
              let totalTrades = option.totalTrades else {
            return false
        }

        let recentTrades = Array(recentTrades.prefix(totalTrades))
        // Successful = ROI > 0 (more accurate than profitLoss > 0)
        let successfulTrades = recentTrades.filter { $0.roi > 0 }

        return successfulTrades.count >= requiredCount
    }

    private func matchesHighestReturnFilter(_ option: FilterSuccessRateOption) -> Bool {
        guard let timePeriod = option.timePeriod else {
            return false
        }

        let cutoffDate = timePeriod.date
        let recentTrades = recentTrades.filter { $0.date >= cutoffDate }
        let maxProfit = recentTrades.map { $0.profitLoss }.max() ?? 0

        return maxProfit > 0
    }

    private func matchesNumberOfTradesFilter(_ option: NumberOfTradesOption) -> Bool {
        guard let minimumCount = option.minimumCount else {
            return false
        }

        return self.recentTrades.count >= minimumCount
    }

    private func matchesTimeRangeFilter(_ option: FilterSuccessRateOption) -> Bool {
        guard let timePeriod = option.timePeriod else {
            return false
        }

        let cutoffDate = timePeriod.date
        return recentTrades.contains { $0.date >= cutoffDate }
    }
}

// MARK: - Financial Metrics Calculations
/// Extension containing financial calculation methods for MockTrader
extension MockTrader {
    var successRate: Double {
        guard !recentTrades.isEmpty else { return 0 }
        // Successful = ROI > 0 (more accurate than profitLoss > 0)
        let successfulTrades = recentTrades.filter { $0.roi > 0 }
        return Double(successfulTrades.count) / Double(recentTrades.count) * 100
    }

    var returnFactor: Double {
        guard !recentTrades.isEmpty else { return 0 }
        // Successful = ROI > 0
        let winningTrades = recentTrades.filter { $0.roi > 0 }
        let losingTrades = recentTrades.filter { $0.roi <= 0 }

        let totalWins = winningTrades.reduce(0) { $0 + $1.profitLoss }
        let totalLosses = abs(losingTrades.reduce(0) { $0 + $1.profitLoss })

        return totalLosses > 0 ? totalWins / totalLosses : 0
    }
}
