import Foundation

@MainActor
extension InvestmentsViewModel {
    // MARK: - Data Loading

    func loadInvestmentsData() {
        isLoading = true

        Task { @MainActor in
            self.loadInvestments()

            // Always reconcile with Parse so server-side deletes (e.g. DEV reset) clear local rows.
            if let user = userService.currentUser {
                print("📡 InvestmentsViewModel: Fetching from backend for \(user.ledgerUserIdCandidates)")
                await investmentService.fetchFromBackend(for: user)
                self.loadInvestments()
            }

            if selectedYear == nil && !availableYears.isEmpty {
                selectedYear = availableYears.first
            }
            isLoading = false
        }
    }

    func loadInvestments() {
        if let user = userService.currentUser {
            let localInvestments = investmentService.getInvestments(matchingAnyOf: user.ledgerUserIdCandidates)
            if !localInvestments.isEmpty {
                investments = localInvestments
            }
        }
        self.refreshCompletedDisplayData()
        self.checkAndUpdateInvestmentCompletion()
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
            let commissionRate = configurationService.effectiveCommissionRate
            let calculationService = InvestorCollectionBillCalculationService()
            let serverOnly = configurationService.investorMonetaryServerOnly

            for inv in investments {
                usernames[inv.id] = traderDataService.getTrader(by: inv.traderId)?.username ?? "---"
                let participations = poolTradeParticipationService.getParticipations(forInvestmentId: inv.id)

                if let first = participations.first,
                   let trade = tradesById[first.tradeId] {
                    tradeNums[inv.id] = String(format: "%03d", trade.tradeNumber)
                } else {
                    tradeNums[inv.id] = "---"
                }
            }
            completedTraderUsernames = usernames
            completedTradeNumbers = tradeNums

            if serverOnly {
                completedInvestmentSummaries = [:]
            } else {
                var summaries: [String: InvestorInvestmentStatementSummary] = [:]
                for inv in investments {
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
                completedInvestmentSummaries = summaries
            }

            self.refreshCompletedCanonicalSummaries(for: investments)
        }
    }

    func refreshCompletedCanonicalSummaries(for investments: [Investment]) {
        let service = settlementAPIService
        guard service != nil else { return }
        let relevantIds = investments
            .filter { $0.status == .completed || $0.reservationStatus == .completed }
            .map { $0.id }
        guard !relevantIds.isEmpty else { return }
        let allowUnweightedFallback = !configurationService.investorMonetaryServerOnly

        Task { [weak self] in
            var result: [String: ServerInvestmentCanonicalSummary] = [:]
            for id in relevantIds {
                if let summary = await ServerCalculatedReturnResolver.resolveCanonicalSummary(
                    investmentId: id,
                    settlementAPIService: service,
                    allowUnweightedReturnFallback: allowUnweightedFallback
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
