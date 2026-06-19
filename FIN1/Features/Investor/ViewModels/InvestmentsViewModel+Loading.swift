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

    /// Summaries und kanonische Server-Totals für Completed-Tabelle (MVVM: keine Logik in der View).
    func refreshCompletedDisplayData() {
        completedInvestmentSummaries = [:]
        self.refreshCompletedCanonicalSummaries(for: investments)
    }

    func refreshCompletedCanonicalSummaries(for investments: [Investment]) {
        let service = settlementAPIService
        guard service != nil else { return }
        let relevantIds = investments
            .filter { $0.status == .completed || $0.reservationStatus == .completed }
            .map(\.id)
        guard !relevantIds.isEmpty else { return }
        let allowUnweightedFallback = !configurationService.investorMonetaryServerOnly

        Task { [weak self] in
            let result = await ServerCalculatedReturnResolver.resolveCanonicalSummaries(
                investmentIds: relevantIds,
                settlementAPIService: service,
                allowUnweightedReturnFallback: allowUnweightedFallback
            )
            await MainActor.run { [weak self] in
                self?.completedCanonicalSummaries = result
            }
        }
    }
}
