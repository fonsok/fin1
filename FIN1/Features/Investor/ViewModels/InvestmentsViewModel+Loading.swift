import Foundation

@MainActor
extension InvestmentsViewModel {
    // MARK: - Data Loading

    func loadInvestmentsData() {
        isLoading = true

        Task { @MainActor in
            loadInvestments()

            // Always reconcile with Parse so server-side deletes (e.g. DEV reset) clear local rows.
            if let investorId = boundInvestorId {
                print("📡 InvestmentsViewModel: Fetching from backend for \(investorId)")
                await investmentService.fetchFromBackend(for: investorId)
                loadInvestments()
            }

            if selectedYear == nil && !availableYears.isEmpty {
                selectedYear = availableYears.first
            }
            isLoading = false
        }
    }

    func loadInvestments() {
        if let investorId = boundInvestorId {
            let localInvestments = investmentService.getInvestments(for: investorId)
            if !localInvestments.isEmpty {
                investments = localInvestments
            }
        }
        refreshCompletedDisplayData()
        checkAndUpdateInvestmentCompletion()
    }

    /// Checks if investments should be marked as completed.
    /// Completion checking is handled by InvestmentCompletionService.
    func checkAndUpdateInvestmentCompletion() {
        // Note: Completion checking is handled by InvestmentCompletionService.
        // This method is kept for compatibility but may not be needed in the same way.
        // The service will handle marking investments as completed when their status is completed.
    }

    /// Trader-Usernames, Trade-Nummern und Summaries für Completed-Tabelle (MVVM: keine Logik in der View).
    func refreshCompletedDisplayData() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            var tradeIds: Set<String> = []
            for inv in investments {
                for p in poolTradeParticipationService.getParticipations(forInvestmentId: inv.id) {
                    tradeIds.insert(p.tradeId)
                }
            }
            let tradesById = await InvestorInvestmentStatementAggregator.resolveTradesForPoolParticipations(
                investedTradeIds: tradeIds,
                localTrades: tradeLifecycleService.completedTrades,
                tradeAPIService: tradeAPIService
            )
            var usernames: [String: String] = [:]
            var tradeNums: [String: String] = [:]
            var summaries: [String: InvestorInvestmentStatementSummary] = [:]
            let commissionRate = configurationService.effectiveCommissionRate
            let calculationService = InvestorCollectionBillCalculationService()
            for inv in investments {
                usernames[inv.id] = traderDataService.getTrader(by: inv.traderId)?.username ?? "---"
                let participations = poolTradeParticipationService.getParticipations(forInvestmentId: inv.id)

                if let first = participations.first,
                   let trade = tradesById[first.tradeId] {
                    tradeNums[inv.id] = String(format: "%03d", trade.tradeNumber)
                } else {
                    tradeNums[inv.id] = "---"
                }
                if let summary = InvestorInvestmentStatementAggregator.summarizeInvestment(
                    investmentId: inv.id,
                    poolTradeParticipationService: poolTradeParticipationService,
                    tradeLifecycleService: tradeLifecycleService,
                    invoiceService: invoiceService,
                    investmentService: investmentService,
                    calculationService: calculationService,
                    commissionCalculationService: commissionCalculationService,
                    additionalTradesById: tradesById,
                    commissionRate: commissionRate
                ) {
                    summaries[inv.id] = summary
                }
            }
            completedTraderUsernames = usernames
            completedTradeNumbers = tradeNums
            completedInvestmentSummaries = summaries

            refreshCompletedCanonicalSummaries(for: investments)
        }
    }

    /// Lädt die server-kanonischen Summaries (ROI2) async. Die View bevorzugt
    /// diese Werte gegenüber `completedInvestmentSummaries` (Fallback).
    func refreshCompletedCanonicalSummaries(for investments: [Investment]) {
        let service = settlementAPIService
        guard service != nil else { return }
        let relevantIds = investments
            .filter { $0.status == .completed || $0.reservationStatus == .completed }
            .map { $0.id }
        guard !relevantIds.isEmpty else { return }

        Task { [weak self] in
            var result: [String: ServerInvestmentCanonicalSummary] = [:]
            for id in relevantIds {
                if let summary = await ServerCalculatedReturnResolver.resolveCanonicalSummary(
                    investmentId: id,
                    settlementAPIService: service
                ) {
                    result[id] = summary
                }
            }
            await MainActor.run { [weak self] in
                self?.completedCanonicalSummaries = result
            }
        }
    }
}
