import Foundation

// MARK: - Transaction Limit Service Implementation
/// Hybrid implementation: Uses Parse Server when available, falls back to in-memory storage
/// Tracks transaction limits based on risk class and regulatory requirements
final class TransactionLimitService: TransactionLimitServiceProtocol {

    // MARK: - Dependencies
    private let userService: any UserServiceProtocol
    private let auditLoggingService: (any AuditLoggingServiceProtocol)?
    private let parseAPIClient: (any ParseAPIClientProtocol)?

    // MARK: - State (protected by stateLock)
    private let stateLock = NSLock()
    private var limits: [String: TransactionLimit] = [:]
    private var transactionHistory: [String: [Date: Double]] = [:] // userId -> [date: amount]
    private var useParseServer: Bool {
        parseAPIClient != nil
    }

    // MARK: - Initialization
    init(
        userService: any UserServiceProtocol,
        auditLoggingService: (any AuditLoggingServiceProtocol)? = nil,
        parseAPIClient: (any ParseAPIClientProtocol)? = nil
    ) {
        self.userService = userService
        self.auditLoggingService = auditLoggingService
        self.parseAPIClient = parseAPIClient
    }

    // MARK: - ServiceLifecycle
    func start() async {
        // Load limits from Parse Server if available
        if useParseServer {
            await loadLimitsFromParseServer()
        }
    }

    func stop() async {
        // Save limits to Parse Server if available
        if useParseServer {
            await saveLimitsToParseServer()
        }
    }

    func reset() {
        stateLock.lock()
        limits.removeAll()
        transactionHistory.removeAll()
        stateLock.unlock()
    }

    // MARK: - TransactionLimitServiceProtocol

    func checkDailyLimit(userId: String, amount: Double) async throws -> Bool {
        let limits = try await getTransactionLimits(userId: userId)
        let checkResult = limits.canSpend(amount: amount)
        return checkResult.isAllowed && checkResult.violations.filter {
            if case .dailyLimitExceeded = $0 { return true }
            return false
        }.isEmpty
    }

    func checkWeeklyLimit(userId: String, amount: Double) async throws -> Bool {
        let limits = try await getTransactionLimits(userId: userId)
        let checkResult = limits.canSpend(amount: amount)
        return checkResult.isAllowed && checkResult.violations.filter {
            if case .weeklyLimitExceeded = $0 { return true }
            return false
        }.isEmpty
    }

    func checkMonthlyLimit(userId: String, amount: Double) async throws -> Bool {
        let limits = try await getTransactionLimits(userId: userId)
        let checkResult = limits.canSpend(amount: amount)
        return checkResult.isAllowed && checkResult.violations.filter {
            if case .monthlyLimitExceeded = $0 { return true }
            return false
        }.isEmpty
    }

    func getRemainingDailyLimit(userId: String) async throws -> Double {
        let limits = try await getTransactionLimits(userId: userId)
        return limits.remainingDailyLimit
    }

    func getRemainingWeeklyLimit(userId: String) async throws -> Double {
        let limits = try await getTransactionLimits(userId: userId)
        return limits.remainingWeeklyLimit
    }

    func getRemainingMonthlyLimit(userId: String) async throws -> Double {
        let limits = try await getTransactionLimits(userId: userId)
        return limits.remainingMonthlyLimit
    }

    func getRiskClassBasedLimit(userId: String) async throws -> Double {
        let limits = try await getTransactionLimits(userId: userId)
        return limits.riskClassBasedLimit
    }

    func checkAllLimits(userId: String, amount: Double) async throws -> TransactionLimitCheckResult {
        let limits = try await getTransactionLimits(userId: userId)
        return limits.canSpend(amount: amount)
    }

    func getTransactionLimits(userId: String) async throws -> TransactionLimit {
        // Return cached limits if available and recent (thread-safe read)
        stateLock.lock()
        if let cached = limits[userId],
           Date().timeIntervalSince(cached.lastUpdated) < 300 { // 5 minutes cache
            stateLock.unlock()
            return cached
        }
        let needsHistory = useParseServer && transactionHistory[userId] == nil
        stateLock.unlock()

        if needsHistory {
            await loadTransactionHistoryFromParseServer(userId: userId)
        }

        // After await, re-check cache — another concurrent call may have populated it
        stateLock.lock()
        if let cached = limits[userId],
           Date().timeIntervalSince(cached.lastUpdated) < 300 {
            stateLock.unlock()
            return cached
        }
        stateLock.unlock()

        guard let user = userService.currentUser else {
            throw AppError.service(.dataNotFound)
        }

        let riskClass = user.riskClass
        let dailyLimit = CalculationConstants.TransactionLimits.dailyLimit(for: riskClass)
        let weeklyLimit = CalculationConstants.TransactionLimits.weeklyLimit(for: riskClass)
        let monthlyLimit = CalculationConstants.TransactionLimits.monthlyLimit(for: riskClass)
        let riskClassBasedLimit = dailyLimit

        let (dailySpent, weeklySpent, monthlySpent) = calculateSpentAmounts(userId: userId)

        let transactionLimit = TransactionLimit(
            userId: userId,
            dailyLimit: dailyLimit,
            weeklyLimit: weeklyLimit,
            monthlyLimit: monthlyLimit,
            riskClassBasedLimit: riskClassBasedLimit,
            dailySpent: dailySpent,
            weeklySpent: weeklySpent,
            monthlySpent: monthlySpent,
            riskClass: riskClass
        )

        // Cache the limits (thread-safe write)
        stateLock.lock()
        limits[userId] = transactionLimit
        stateLock.unlock()

        if useParseServer {
            Task { [weak self] in
                await self?.saveLimitsToParseServer()
            }
        }

        return transactionLimit
    }

    func recordTransaction(userId: String, amount: Double) async throws {
        let now = Date()
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: now)

        if useParseServer, let parseClient = parseAPIClient {
            do {
                let parseHistory = ParseTransactionHistory(
                    userId: userId,
                    date: dateKey,
                    amount: amount,
                    transactionType: "transaction"
                )
                _ = try await parseClient.createObject(
                    className: "TransactionHistory",
                    object: parseHistory
                )
            } catch {
                print("⚠️ Failed to save transaction to Parse Server, using in-memory: \(error.localizedDescription)")
            }
        }

        stateLock.lock()
        if transactionHistory[userId] == nil {
            transactionHistory[userId] = [:]
        }
        let currentAmount = transactionHistory[userId]?[dateKey] ?? 0.0
        transactionHistory[userId]?[dateKey] = currentAmount + amount
        limits.removeValue(forKey: userId)
        stateLock.unlock()

        // ✅ Log limit usage for compliance
        if let auditService = auditLoggingService {
            let complianceEvent = ComplianceEvent(
                eventType: .riskCheck,
                agentId: userId,
                customerId: userId,
                description: "Transaction recorded: €\(amount.formatted(.number.precision(.fractionLength(2))))",
                severity: .low,
                requiresReview: false,
                notes: "User ID: \(userId), Date: \(dateKey.formatted(date: .abbreviated, time: .omitted))"
            )
            Task {
                await auditService.logComplianceEvent(complianceEvent)
            }
        }
    }

    // MARK: - Private Methods - Parse Server Integration

    private func loadLimitsFromParseServer() async {
        guard let parseClient = parseAPIClient,
              let userId = userService.currentUser?.id else {
            return
        }

        do {
            let parseLimits: [ParseTransactionLimit] = try await parseClient.fetchObjects(
                className: "TransactionLimit",
                query: ["userId": userId],
                include: nil,
                orderBy: nil,
                limit: 1
            )

            if let parseLimit = parseLimits.first,
               let user = userService.currentUser {
                stateLock.lock()
                limits[userId] = parseLimit.toTransactionLimit(riskClass: user.riskClass)
                stateLock.unlock()
            }
        } catch {
            print("⚠️ Failed to load limits from Parse Server: \(error.localizedDescription)")
        }
    }

    private func saveLimitsToParseServer() async {
        guard let parseClient = parseAPIClient else {
            return
        }

        stateLock.lock()
        let limitsCopy = limits
        stateLock.unlock()

        for (userId, limit) in limitsCopy {
            do {
                let parseLimit = ParseTransactionLimit(
                    objectId: nil, // Will be set by Parse Server if new
                    userId: userId,
                    dailyLimit: limit.dailyLimit,
                    weeklyLimit: limit.weeklyLimit,
                    monthlyLimit: limit.monthlyLimit,
                    riskClassBasedLimit: limit.riskClassBasedLimit,
                    dailySpent: limit.dailySpent,
                    weeklySpent: limit.weeklySpent,
                    monthlySpent: limit.monthlySpent,
                    lastUpdated: limit.lastUpdated
                )

                // Try to find existing limit first
                let existing: [ParseTransactionLimit] = try await parseClient.fetchObjects(
                    className: "TransactionLimit",
                    query: ["userId": userId],
                    include: nil,
                    orderBy: nil,
                    limit: 1
                )

                if let existingLimit = existing.first, let objectId = existingLimit.objectId {
                    // Update existing
                    _ = try await parseClient.updateObject(
                        className: "TransactionLimit",
                        objectId: objectId,
                        object: parseLimit
                    )
                } else {
                    // Create new
                    _ = try await parseClient.createObject(
                        className: "TransactionLimit",
                        object: parseLimit
                    )
                }
            } catch {
                print("⚠️ Failed to save limits to Parse Server: \(error.localizedDescription)")
            }
        }
    }

    private func loadTransactionHistoryFromParseServer(userId: String) async {
        guard let parseClient = parseAPIClient else {
            return
        }

        do {
            let now = Date()
            let calendar = Calendar.current
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

            // Parse Server expects ISO8601 date strings in queries
            let parseHistory: [ParseTransactionHistory] = try await parseClient.fetchObjects(
                className: "TransactionHistory",
                query: [
                    "userId": userId,
                    "date": ["$gte": ["__type": "Date", "iso": weekAgo.iso8601String]]
                ],
                include: nil,
                orderBy: "-date",
                limit: 100
            )

            var history: [Date: Double] = [:]
            for entry in parseHistory {
                let dateKey = calendar.startOfDay(for: entry.date)
                let currentAmount = history[dateKey] ?? 0.0
                history[dateKey] = currentAmount + entry.amount
            }
            stateLock.lock()
            transactionHistory[userId] = history
            stateLock.unlock()
        } catch {
            print("⚠️ Failed to load transaction history from Parse Server: \(error.localizedDescription)")
        }
    }

    private func calculateSpentAmounts(userId: String) -> (daily: Double, weekly: Double, monthly: Double) {
        stateLock.lock()
        guard let history = transactionHistory[userId] else {
            stateLock.unlock()
            return (0.0, 0.0, 0.0)
        }
        let historyCopy = history
        stateLock.unlock()

        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now

        var dailySpent: Double = 0.0
        var weeklySpent: Double = 0.0
        var monthlySpent: Double = 0.0

        for (date, amount) in historyCopy {
            if date == today {
                dailySpent += amount
            }
            if date >= calendar.startOfDay(for: weekAgo) {
                weeklySpent += amount
            }
            if date >= calendar.startOfDay(for: monthAgo) {
                monthlySpent += amount
            }
        }

        return (dailySpent, weeklySpent, monthlySpent)
    }
}
