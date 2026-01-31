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
protocol InvestorCollectionBillCalculationServiceProtocol {
    /// Calculates collection bill values for a single trade participation
    /// - Parameter input: Input data containing investment capital, trade data, invoices, and ownership
    /// - Returns: Calculated collection bill output with all buy/sell amounts, quantities, fees, and profit
    /// - Throws: Validation errors if input data is invalid or inconsistent
    func calculateCollectionBill(input: InvestorCollectionBillInput) throws -> InvestorCollectionBillOutput

    /// Validates input data for collection bill calculation
    /// - Parameter input: Input data to validate
    /// - Returns: Validation result with any errors or warnings
    func validateInput(_ input: InvestorCollectionBillInput) -> ValidationResult
}
