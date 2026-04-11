import Foundation

// MARK: - App Ledger Service Protocol

/// Provides read access to the app ledger (Eigenkonten).
/// All ledger writes are performed server-side (Parse Cloud Triggers / 4-Eyes approval).
/// iOS acts as a thin API client for display and reporting only.
protocol AppLedgerServiceProtocol: ServiceLifecycle {

    /// Fetches the latest ledger data from the backend.
    func refreshFromBackend() async throws

    // MARK: - Read (cached from last backend fetch)

    func getEntries(
        account: AppLedgerAccount?,
        userId: String?,
        transactionType: AppLedgerTransactionType?
    ) -> [AppLedgerEntry]

    func getAllEntries() -> [AppLedgerEntry]
    func getAccountSummaries() -> [AppLedgerAccountSummary]
    func getTotalAppRevenue() -> Double
    func getVATSummary() -> AppVATSummary
}

// MARK: - Backend Response Model

private struct AppLedgerResponse: Decodable {
    let entries: [BackendLedgerEntry]
    let totals: [String: AccountTotals]
    let totalRevenue: Double
    let totalRefunds: Double
    let vatSummary: BackendVATSummary
    let totalCount: Int

    struct BackendLedgerEntry: Decodable {
        let id: String
        let account: String
        let side: String
        let amount: Double
        let userId: String
        let userRole: String
        let transactionType: String
        let referenceId: String
        let referenceType: String
        let description: String
        let createdAt: Date?
        let metadata: [String: String]?

        enum CodingKeys: String, CodingKey {
            case id, account, side, amount, userId, userRole,
                 transactionType, referenceId, referenceType,
                 description, createdAt, metadata
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            account = try c.decode(String.self, forKey: .account)
            side = try c.decode(String.self, forKey: .side)
            amount = try c.decode(Double.self, forKey: .amount)
            userId = (try? c.decode(String.self, forKey: .userId)) ?? ""
            userRole = (try? c.decode(String.self, forKey: .userRole)) ?? ""
            transactionType = (try? c.decode(String.self, forKey: .transactionType)) ?? ""
            referenceId = (try? c.decode(String.self, forKey: .referenceId)) ?? ""
            referenceType = (try? c.decode(String.self, forKey: .referenceType)) ?? ""
            description = (try? c.decode(String.self, forKey: .description)) ?? ""
            createdAt = try? c.decode(Date.self, forKey: .createdAt)

            if let dict = try? c.decode([String: String].self, forKey: .metadata) {
                metadata = dict
            } else {
                metadata = nil
            }
        }
    }

    struct AccountTotals: Decodable {
        let credit: Double
        let debit: Double
        let net: Double
    }

    struct BackendVATSummary: Decodable {
        let outputVATCollected: Double
        let outputVATRemitted: Double
        let inputVATClaimed: Double
        let outstandingVATLiability: Double
    }
}

// MARK: - App Ledger Service Implementation (Backend API Client)

final class AppLedgerService: AppLedgerServiceProtocol {

    private let parseAPIClient: any ParseAPIClientProtocol
    private let queue = DispatchQueue(label: "com.fin.app.appLedger", attributes: .concurrent)

    // Cached data from last backend fetch
    private var cachedEntries: [AppLedgerEntry] = []
    private var cachedSummaries: [AppLedgerAccountSummary] = []
    private var cachedRevenue: Double = 0
    private var cachedVATSummary = AppVATSummary(
        outputVATCollected: 0, outputVATRemitted: 0, inputVATClaimed: 0
    )

    init(parseAPIClient: any ParseAPIClientProtocol) {
        self.parseAPIClient = parseAPIClient
    }

    // MARK: - ServiceLifecycle

    func start() {
        print("🏛️ AppLedgerService started (backend-authoritative)")
    }

    func stop() {
        print("🏛️ AppLedgerService stopped")
    }

    func reset() {
        queue.async(flags: .barrier) {
            self.cachedEntries = []
            self.cachedSummaries = []
            self.cachedRevenue = 0
            self.cachedVATSummary = AppVATSummary(
                outputVATCollected: 0, outputVATRemitted: 0, inputVATClaimed: 0
            )
        }
    }

    // MARK: - Backend Refresh

    func refreshFromBackend() async throws {
        let response: AppLedgerResponse = try await parseAPIClient.callFunction(
            "getAppLedger",
            parameters: ["limit": 1000]
        )

        let entries = response.entries.compactMap { self.mapEntry($0) }
        let summaries = self.buildSummaries(from: response.totals)
        let vatSummary = AppVATSummary(
            outputVATCollected: response.vatSummary.outputVATCollected,
            outputVATRemitted: response.vatSummary.outputVATRemitted,
            inputVATClaimed: response.vatSummary.inputVATClaimed
        )

        queue.async(flags: .barrier) {
            self.cachedEntries = entries
            self.cachedSummaries = summaries
            self.cachedRevenue = response.totalRevenue
            self.cachedVATSummary = vatSummary
        }

        print("🏛️ AppLedgerService: refreshed \(entries.count) entries from backend")
    }

    // MARK: - Read (cached)

    func getEntries(
        account: AppLedgerAccount? = nil,
        userId: String? = nil,
        transactionType: AppLedgerTransactionType? = nil
    ) -> [AppLedgerEntry] {
        queue.sync {
            cachedEntries.filter { entry in
                let matchesAccount = account.map { $0 == entry.account } ?? true
                let matchesUser = userId.map { $0 == entry.userId } ?? true
                let matchesType = transactionType.map { $0 == entry.transactionType } ?? true
                return matchesAccount && matchesUser && matchesType
            }
            .sorted { $0.createdAt < $1.createdAt }
        }
    }

    func getAllEntries() -> [AppLedgerEntry] {
        getEntries()
    }

    func getAccountSummaries() -> [AppLedgerAccountSummary] {
        queue.sync { cachedSummaries }
    }

    func getTotalAppRevenue() -> Double {
        queue.sync { cachedRevenue }
    }

    func getVATSummary() -> AppVATSummary {
        queue.sync { cachedVATSummary }
    }

    // MARK: - Mapping

    private func mapEntry(_ e: AppLedgerResponse.BackendLedgerEntry) -> AppLedgerEntry? {
        guard let account = AppLedgerAccount(rawValue: e.account),
              let side = AppLedgerSide(rawValue: e.side) else {
            return nil
        }
        let txType = AppLedgerTransactionType(rawValue: e.transactionType) ?? .adjustment

        return AppLedgerEntry(
            id: UUID(uuidString: e.id) ?? UUID(),
            account: account,
            side: side,
            amount: e.amount,
            userId: e.userId,
            userRole: e.userRole,
            transactionType: txType,
            referenceId: e.referenceId,
            referenceType: e.referenceType,
            description: e.description,
            createdAt: e.createdAt ?? Date(),
            metadata: e.metadata ?? [:]
        )
    }

    private func buildSummaries(
        from totals: [String: AppLedgerResponse.AccountTotals]
    ) -> [AppLedgerAccountSummary] {
        totals.compactMap { code, t in
            guard let account = AppLedgerAccount(rawValue: code) else { return nil }
            return AppLedgerAccountSummary(
                account: account,
                totalCredits: t.credit,
                totalDebits: t.debit
            )
        }
    }
}
