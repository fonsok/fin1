import Foundation

// MARK: - Transaction Limit Service Protocol
/// Protocol for managing transaction limits based on risk class and regulatory requirements
protocol TransactionLimitServiceProtocol: ServiceLifecycle {
    /// Checks if a transaction amount is within daily limit
    /// - Parameters:
    ///   - userId: User ID
    ///   - amount: Transaction amount to check
    /// - Returns: True if within limit, false otherwise
    /// - Throws: AppError if check fails
    func checkDailyLimit(userId: String, amount: Double) async throws -> Bool
    
    /// Checks if a transaction amount is within weekly limit
    /// - Parameters:
    ///   - userId: User ID
    ///   - amount: Transaction amount to check
    /// - Returns: True if within limit, false otherwise
    /// - Throws: AppError if check fails
    func checkWeeklyLimit(userId: String, amount: Double) async throws -> Bool
    
    /// Checks if a transaction amount is within monthly limit
    /// - Parameters:
    ///   - userId: User ID
    ///   - amount: Transaction amount to check
    /// - Returns: True if within limit, false otherwise
    /// - Throws: AppError if check fails
    func checkMonthlyLimit(userId: String, amount: Double) async throws -> Bool
    
    /// Gets remaining daily limit for a user
    /// - Parameter userId: User ID
    /// - Returns: Remaining daily limit amount
    /// - Throws: AppError if retrieval fails
    func getRemainingDailyLimit(userId: String) async throws -> Double
    
    /// Gets remaining weekly limit for a user
    /// - Parameter userId: User ID
    /// - Returns: Remaining weekly limit amount
    /// - Throws: AppError if retrieval fails
    func getRemainingWeeklyLimit(userId: String) async throws -> Double
    
    /// Gets remaining monthly limit for a user
    /// - Parameter userId: User ID
    /// - Returns: Remaining monthly limit amount
    /// - Throws: AppError if retrieval fails
    func getRemainingMonthlyLimit(userId: String) async throws -> Double
    
    /// Gets risk class based limit for a user
    /// - Parameter userId: User ID
    /// - Returns: Risk class based limit amount
    /// - Throws: AppError if retrieval fails
    func getRiskClassBasedLimit(userId: String) async throws -> Double
    
    /// Checks all limits for a transaction amount
    /// - Parameters:
    ///   - userId: User ID
    ///   - amount: Transaction amount to check
    /// - Returns: TransactionLimitCheckResult with detailed information
    /// - Throws: AppError if check fails
    func checkAllLimits(userId: String, amount: Double) async throws -> TransactionLimitCheckResult
    
    /// Gets current transaction limits for a user
    /// - Parameter userId: User ID
    /// - Returns: TransactionLimit with current limits and spending
    /// - Throws: AppError if retrieval fails
    func getTransactionLimits(userId: String) async throws -> TransactionLimit
    
    /// Records a transaction to update spending counters
    /// - Parameters:
    ///   - userId: User ID
    ///   - amount: Transaction amount
    /// - Throws: AppError if recording fails
    func recordTransaction(userId: String, amount: Double) async throws
}
