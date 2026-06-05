import Foundation

// MARK: - Discover filter matching (no MockTrader bridge)

extension InvestorTrader {
    func matchesFilterCriteria(_ criteria: IndividualFilterCriteria) -> Bool {
        switch criteria.type {
        case .returnRate:
            if let option = criteria.returnPercentageOption {
                return self.matchesReturnRateFilter(option)
            }
            return false
        case .recentSuccessfulTrades:
            if let option = criteria.successRateOption {
                return self.matchesRecentSuccessfulTradesFilter(option)
            }
            return false
        case .highestReturn:
            if let option = criteria.successRateOption {
                return self.matchesHighestReturnFilter(option)
            }
            return false
        case .numberOfTrades:
            if let option = criteria.numberOfTradesOption {
                return self.matchesNumberOfTradesFilter(option)
            }
            return false
        case .timeRange:
            if let option = criteria.successRateOption {
                return self.matchesTimeRangeFilter(option)
            }
            return false
        }
    }

    func matchesFilterCombination(_ combination: FilterCombination) -> Bool {
        combination.filters.allSatisfy { self.matchesFilterCriteria($0) }
    }

    // MARK: - Private

    private func matchesReturnRateFilter(_ option: ReturnPercentageOption) -> Bool {
        guard let minimumPercentage = option.minimumPercentage else { return false }
        guard !self.recentTrades.isEmpty else { return false }
        let totalROI = self.recentTrades.reduce(0.0) { $0 + $1.roi }
        let averageROI = totalROI / Double(self.recentTrades.count)
        return averageROI >= minimumPercentage
    }

    private func matchesRecentSuccessfulTradesFilter(_ option: FilterSuccessRateOption) -> Bool {
        guard let requiredCount = option.requiredSuccessCount,
              let totalTrades = option.totalTrades else { return false }
        let slice = Array(self.recentTrades.prefix(totalTrades))
        let successfulTrades = slice.filter { $0.roi > 0 }
        return successfulTrades.count >= requiredCount
    }

    private func matchesHighestReturnFilter(_ option: FilterSuccessRateOption) -> Bool {
        guard let timePeriod = option.timePeriod else { return false }
        let cutoffDate = timePeriod.date
        let slice = self.recentTrades.filter { $0.date >= cutoffDate }
        let maxProfit = slice.map(\.profitLoss).max() ?? 0
        return maxProfit > 0
    }

    private func matchesNumberOfTradesFilter(_ option: NumberOfTradesOption) -> Bool {
        guard let minimumCount = option.minimumCount else { return false }
        return self.recentTrades.count >= minimumCount
    }

    private func matchesTimeRangeFilter(_ option: FilterSuccessRateOption) -> Bool {
        guard let timePeriod = option.timePeriod else { return false }
        let cutoffDate = timePeriod.date
        return self.recentTrades.contains { $0.date >= cutoffDate }
    }
}
