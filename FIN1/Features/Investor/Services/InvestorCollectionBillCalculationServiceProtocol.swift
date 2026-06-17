import Foundation

// MARK: - Investor Collection Bill Calculation Service Protocol

/// Service for calculating investor collection bill values (buy/sell amounts, quantities, fees, profit)
///
/// **Purpose**: Centralizes all collection bill calculation logic to ensure consistency and maintainability.
/// This service extracts business logic from ViewModels and provides a single source of truth for calculations.
///
/// **Data Source Hierarchy**:
/// 1. `Investment.amount` (CAPITAL) - Source of truth for buy amount
/// 2. `Trade.entryPrice` - Source of truth for buy price
/// 3. `Invoice` (fees) - Source of truth for fees
/// 4. `Invoice` (sell prices) - Source of truth for sell prices
/// 5. `Trade.totalQuantity` - Reference for sell percentage calculation
///
/// **Documentation**: See `Documentation/DATA_SOURCE_HIERARCHY.md` for complete data source hierarchy and calculation rules.
@MainActor
protocol InvestorCollectionBillCalculationServiceProtocol {
    /// Local mirror-basis calculation — tests/dev only (`InvestorCollectionBillLocalCalculationGate`).
    /// - Throws: When gate is not permitted (production uses server Beleg metadata only).
    func calculateCollectionBill(input: InvestorCollectionBillInput) throws -> InvestorCollectionBillOutput

    /// Validates input data for collection bill calculation
    /// - Parameter input: Input data to validate
    /// - Returns: Validation result with any errors or warnings
    func validateInput(_ input: InvestorCollectionBillInput) -> ValidationResult

    /// Builds collection bill output from backend Beleg data only (no local recompute in production).
    /// Set ``billResolvedFromPrefetchIndex`` when ``preloadedBill`` came from a prefetch map lookup (nil = no bill).
    func calculateCollectionBillWithBackend(
        input: InvestorCollectionBillInput,
        settlementAPIService: (any SettlementAPIServiceProtocol)?,
        tradeId: String?,
        investmentId: String?,
        preloadedBill: BackendCollectionBill?,
        monetaryServerOnly: Bool,
        collectionBillServerLegs: Bool,
        billResolvedFromPrefetchIndex: Bool
    ) async throws -> InvestorCollectionBillOutput

    /// One API call per investment — use before building multi-trade statements.
    func prefetchBackendBills(
        for investmentId: String,
        settlementAPIService: any SettlementAPIServiceProtocol
    ) async throws -> [String: BackendCollectionBill]
}

extension InvestorCollectionBillCalculationServiceProtocol {
    func calculateCollectionBillWithBackend(
        input: InvestorCollectionBillInput,
        settlementAPIService: (any SettlementAPIServiceProtocol)?,
        tradeId: String?,
        investmentId: String?,
        preloadedBill: BackendCollectionBill?
    ) async throws -> InvestorCollectionBillOutput {
        try await self.calculateCollectionBillWithBackend(
            input: input,
            settlementAPIService: settlementAPIService,
            tradeId: tradeId,
            investmentId: investmentId,
            preloadedBill: preloadedBill,
            monetaryServerOnly: false,
            collectionBillServerLegs: false,
            billResolvedFromPrefetchIndex: preloadedBill != nil
        )
    }
}
