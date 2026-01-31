import Foundation

// MARK: - Investment Completion Checker
/// Handles checking and updating investment completion status
/// Extracted from InvestmentService to follow single responsibility principle
struct InvestmentCompletionChecker {

    // MARK: - Check All Investments

    /// Checks and updates completion status for all investments
    /// - Parameters:
    ///   - repository: Investment repository
    ///   - investmentCompletionService: Service for completion checking
    @MainActor
    static func checkAndUpdateAll(
        repository: any InvestmentRepositoryProtocol,
        investmentCompletionService: (any InvestmentCompletionServiceProtocol)?
    ) {
        guard let investmentCompletionService = investmentCompletionService else {
            print("⚠️ InvestmentCompletionChecker: investmentCompletionService is nil - using fallback")
            return
        }

        let updatedInvestments = investmentCompletionService.checkAndUpdateInvestmentCompletion(
            in: repository.investments,
            specificInvestmentIds: nil // Check all investments
        )

        updateRepository(repository: repository, with: updatedInvestments)

        if !updatedInvestments.isEmpty {
            print("   📡 Updated \(updatedInvestments.count) investments in repository")
            print("   📡 Repository investments count: \(repository.investments.count)")
        }
    }

    // MARK: - Check Specific Investments

    /// Checks and updates completion status for specific investments only
    /// - Parameters:
    ///   - investmentIds: IDs of investments to check
    ///   - repository: Investment repository
    ///   - investmentCompletionService: Service for completion checking
    @MainActor
    static func checkAndUpdate(
        for investmentIds: [String],
        repository: any InvestmentRepositoryProtocol,
        investmentCompletionService: (any InvestmentCompletionServiceProtocol)?
    ) {
        guard let investmentCompletionService = investmentCompletionService else {
            print("⚠️ InvestmentCompletionChecker: investmentCompletionService is nil - using fallback")
            return
        }

        let updatedInvestments = investmentCompletionService.checkAndUpdateInvestmentCompletion(
            in: repository.investments,
            specificInvestmentIds: investmentIds
        )

        updateRepository(repository: repository, with: updatedInvestments)

        if !updatedInvestments.isEmpty {
            print("   📡 Updated \(updatedInvestments.count) investments in repository (specific check)")
        }
    }

    // MARK: - Update Profits from Trades

    /// Updates investment profits from completed trades
    /// - Parameters:
    ///   - repository: Investment repository
    ///   - investmentCompletionService: Service for profit calculation
    @MainActor
    static func updateProfitsFromTrades(
        repository: any InvestmentRepositoryProtocol,
        investmentCompletionService: (any InvestmentCompletionServiceProtocol)?
    ) {
        guard let investmentCompletionService = investmentCompletionService else {
            print("⚠️ InvestmentCompletionChecker: investmentCompletionService is nil - using fallback")
            return
        }

        let updatedInvestments = investmentCompletionService.updateInvestmentProfitsFromTrades(
            in: repository.investments
        )

        updateRepository(repository: repository, with: updatedInvestments)

        if !updatedInvestments.isEmpty {
            print("   📡 Updated \(updatedInvestments.count) investment profits in repository")
        }
    }

    // MARK: - Private Helpers

    @MainActor
    private static func updateRepository(
        repository: any InvestmentRepositoryProtocol,
        with updatedInvestments: [Investment]
    ) {
        for updatedInvestment in updatedInvestments {
            if let index = repository.investments.firstIndex(where: { $0.id == updatedInvestment.id }) {
                repository.investments[index] = updatedInvestment
            }
        }
    }
}











