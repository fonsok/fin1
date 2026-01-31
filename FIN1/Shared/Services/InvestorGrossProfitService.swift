import Foundation

// MARK: - Investor Gross Profit Service Protocol

/// Single source of truth for investor gross profit calculations
/// Uses the same calculation method as Collection Bill to ensure consistency
protocol InvestorGrossProfitServiceProtocol: ServiceLifecycle {
    /// Gets the gross profit for a specific investor's investment in a specific trade
    /// - Parameters:
    ///   - investmentId: The investment ID
    ///   - tradeId: The trade ID
    /// - Returns: Gross profit amount (same as shown in Collection Bill)
    func getGrossProfit(
        for investmentId: String,
        tradeId: String
    ) async throws -> Double

    /// Gets gross profit for all investments participating in a trade
    /// - Parameter tradeId: The trade ID
    /// - Returns: Dictionary mapping investmentId to gross profit
    func getGrossProfitsForTrade(
        tradeId: String
    ) async throws -> [String: Double]
}

// MARK: - Investor Gross Profit Service Implementation

/// Single source of truth service for investor gross profit
/// Delegates to InvestorCollectionBillCalculationService to ensure consistency with Collection Bill
final class InvestorGrossProfitService: InvestorGrossProfitServiceProtocol, ObservableObject {

    // MARK: - Dependencies
    private let poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    private let tradeLifecycleService: any TradeLifecycleServiceProtocol
    private let invoiceService: any InvoiceServiceProtocol
    private let investmentService: any InvestmentServiceProtocol
    private let calculationService: any InvestorCollectionBillCalculationServiceProtocol

    // MARK: - Initialization
    init(
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        calculationService: any InvestorCollectionBillCalculationServiceProtocol
    ) {
        self.poolTradeParticipationService = poolTradeParticipationService
        self.tradeLifecycleService = tradeLifecycleService
        self.invoiceService = invoiceService
        self.investmentService = investmentService
        self.calculationService = calculationService
    }

    // MARK: - ServiceLifecycle
    func start() {
        print("💰 InvestorGrossProfitService started")
    }

    func stop() {
        print("💰 InvestorGrossProfitService stopped")
    }

    func reset() {
        print("💰 InvestorGrossProfitService reset")
    }

    // MARK: - Public Methods

    func getGrossProfit(
        for investmentId: String,
        tradeId: String
    ) async throws -> Double {
        // Use InvestorInvestmentStatementAggregator to get the exact gross profit from Collection Bill
        // This ensures we use the same calculation and values as the Collection Bill
        guard let summary = InvestorInvestmentStatementAggregator.summarizeInvestment(
            investmentId: investmentId,
            poolTradeParticipationService: poolTradeParticipationService,
            tradeLifecycleService: tradeLifecycleService,
            invoiceService: invoiceService,
            investmentService: investmentService,
            calculationService: calculationService,
            commissionCalculationService: nil  // Use default
        ) else {
            throw AppError.serviceError(.dataNotFound)
        }

        // Find all statement items that match THIS specific trade
        // An investment can have multiple participations in the same trade, so we need to sum them
        let statementItemsForThisTrade = summary.items.filter { $0.id == tradeId }

        guard !statementItemsForThisTrade.isEmpty else {
            throw AppError.serviceError(.dataNotFound)
        }

        // Sum up gross profit from all participations in this trade
        // This matches how Collection Bill aggregates multiple participations
        return statementItemsForThisTrade.reduce(0.0) { $0 + $1.grossProfit }
    }

    func getGrossProfitsForTrade(
        tradeId: String
    ) async throws -> [String: Double] {
        // Get all participations for this trade
        let participations = poolTradeParticipationService.getParticipations(forTradeId: tradeId)

        guard !participations.isEmpty else {
            return [:]
        }

        // Group participations by investment to get unique investments
        let participationsByInvestment = Dictionary(grouping: participations) { $0.investmentId }
        let allInvestmentIds = Set(participationsByInvestment.keys)

        var result: [String: Double] = [:]
        var failedInvestments: [String] = []

        // Get gross profit for each investment
        for (investmentId, _) in participationsByInvestment {
            do {
                let grossProfit = try await getGrossProfit(for: investmentId, tradeId: tradeId)
                result[investmentId] = grossProfit
            } catch {
                print("⚠️ InvestorGrossProfitService: Failed to get gross profit for investment \(investmentId): \(error)")
                failedInvestments.append(investmentId)
                // Continue with other investments
            }
        }

        // VALIDATION: Ensure all investments with participations are included
        let successfulInvestmentIds = Set(result.keys)
        let missingInvestments = allInvestmentIds.subtracting(successfulInvestmentIds)

        if !missingInvestments.isEmpty {
            let missingCount = missingInvestments.count
            let totalCount = allInvestmentIds.count
            print("🚨 InvestorGrossProfitService: VALIDATION FAILED")
            print("   Trade ID: \(tradeId)")
            print("   Total investments with participations: \(totalCount)")
            print("   Successfully calculated: \(successfulInvestmentIds.count)")
            print("   Missing/Failed: \(missingCount)")
            print("   Missing investment IDs: \(missingInvestments)")

            // If ALL investments failed, throw error
            if successfulInvestmentIds.isEmpty {
                throw AppError.serviceError(.dataNotFound)
            }

            // If SOME investments failed, log warning but return partial result
            // This allows commission calculation to proceed with available data
            // but alerts that some investments are missing
            print("⚠️ WARNING: Commission calculation will be incomplete - missing \(missingCount) investment(s)")
        } else {
            print("✅ InvestorGrossProfitService: All \(allInvestmentIds.count) investments successfully calculated")
        }

        return result
    }
}
