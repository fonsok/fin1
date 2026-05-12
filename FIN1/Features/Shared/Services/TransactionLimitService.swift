import Foundation

// MARK: - Transaction limit mutable state (Swift 6–safe isolation)

private actor TransactionLimitMutableState {
    private var limits: [String: TransactionLimit] = [:]
    private var transactionHistory: [String: [Date: Double]] = [:]

    private let cacheTTL: TimeInterval = 300

    func reset() {
        limits.removeAll()
        transactionHistory.removeAll()
    }

    func validCachedLimit(for userId: String) -> TransactionLimit? {
        guard let cached = limits[userId],
              Date().timeIntervalSince(cached.lastUpdated) < cacheTTL else { return nil }
        return cached
    }

    func needsHistoryLoad(userId: String, useParseServer: Bool) -> Bool {
        useParseServer && transactionHistory[userId] == nil
    }

    func setLimit(_ limit: TransactionLimit, for userId: String) {
        limits[userId] = limit
    }

    func setLimitFromParse(_ limit: TransactionLimit, userId: String) {
        limits[userId] = limit
    }

    func replaceTransactionHistory(_ history: [Date: Double], for userId: String) {
        transactionHistory[userId] = history
    }

    func recordLocalSpend(userId: String, dateKey: Date, amount: Double) {
        if transactionHistory[userId] == nil {
            transactionHistory[userId] = [:]
        }
        let prior = transactionHistory[userId]?[dateKey] ?? 0.0
        transactionHistory[userId]?[dateKey] = prior + amount
        limits.removeValue(forKey: userId)
    }

    func allLimits() -> [String: TransactionLimit] {
        limits
    }

    func calculateSpentAmounts(userId: String) -> (daily: Double, weekly: Double, monthly: Double) {
        guard let history = transactionHistory[userId] else {
            return (0.0, 0.0, 0.0)
        }

        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now

        var dailySpent: Double = 0.0
        var weeklySpent: Double = 0.0
        var monthlySpent: Double = 0.0

        for (date, amount) in history {
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

// MARK: - Transaction Limit Service Implementation
/// Hybrid implementation: Uses Parse Server when available, falls back to in-memory storage
/// Tracks transaction limits based on risk class and regulatory requirements
final class TransactionLimitService: TransactionLimitServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies
    private let userService: any UserServiceProtocol
    private let auditLoggingService: (any AuditLoggingServiceProtocol)?
    private let parseAPIClient: (any ParseAPIClientProtocol)?

    private let mutableState = TransactionLimitMutableState()

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
        let state = mutableState
        Task { await state.reset() }
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
        if let cached = await mutableState.validCachedLimit(for: userId) {
            return cached
        }

        let needsHistory = await mutableState.needsHistoryLoad(userId: userId, useParseServer: useParseServer)
        if needsHistory {
            await loadTransactionHistoryFromParseServer(userId: userId)
        }

        if let cached = await mutableState.validCachedLimit(for: userId) {
            return cached
        }

        guard userService.currentUser != nil else {
            throw AppError.service(.dataNotFound)
        }

        // Authoritative limits come from admin configuration / Parse; constants are last-resort fallback.
        let dailyLimit = CalculationConstants.TransactionLimits.baseDailyLimit
        let weeklyLimit = CalculationConstants.TransactionLimits.baseWeeklyLimit
        let monthlyLimit = CalculationConstants.TransactionLimits.baseMonthlyLimit
        let riskClassBasedLimit = dailyLimit

        let spent = await mutableState.calculateSpentAmounts(userId: userId)

        let transactionLimit = TransactionLimit(
            userId: userId,
            dailyLimit: dailyLimit,
            weeklyLimit: weeklyLimit,
            monthlyLimit: monthlyLimit,
            riskClassBasedLimit: riskClassBasedLimit,
            dailySpent: spent.daily,
            weeklySpent: spent.weekly,
            monthlySpent: spent.monthly
        )

        await mutableState.setLimit(transactionLimit, for: userId)

        if useParseServer, let client = parseAPIClient {
            let limitsToSave = await mutableState.allLimits()
            await Self.persistLimitsSnapshot(limitsToSave, parseClient: client)
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

        await mutableState.recordLocalSpend(userId: userId, dateKey: dateKey, amount: amount)

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
            await auditService.logComplianceEvent(complianceEvent)
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

            if let parseLimit = parseLimits.first {
                await mutableState.setLimitFromParse(parseLimit.toTransactionLimit(), userId: userId)
            }
        } catch {
            print("⚠️ Failed to load limits from Parse Server: \(error.localizedDescription)")
        }
    }

    private static func persistLimitsSnapshot(
        _ limitsSnapshot: [String: TransactionLimit],
        parseClient: any ParseAPIClientProtocol
    ) async {
        for (userId, limit) in limitsSnapshot {
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
                    _ = try await parseClient.updateObject(
                        className: "TransactionLimit",
                        objectId: objectId,
                        object: parseLimit
                    )
                } else {
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

    private func saveLimitsToParseServer() async {
        guard let parseClient = parseAPIClient else { return }
        let limitsCopy = await mutableState.allLimits()
        await Self.persistLimitsSnapshot(limitsCopy, parseClient: parseClient)
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
            await mutableState.replaceTransactionHistory(history, for: userId)
        } catch {
            print("⚠️ Failed to load transaction history from Parse Server: \(error.localizedDescription)")
        }
    }
}
