import Foundation

/// Shared entry source for monthly statements — same SSOT as `AccountStatementViewModel`.
enum MonthlyAccountStatementDataSource {
    struct Snapshot {
        let entries: [AccountStatementEntry]
        let openingBalance: Double
        let closingBalance: Double
        let timelineTruncated: Bool
    }

    @MainActor
    static func loadSnapshot(for user: User, services: AppServices) async -> Snapshot {
        switch user.role {
        case .investor:
            let snapshot = await InvestorAccountStatementBuilder.buildSnapshotWithWallet(
                for: user,
                investorCashBalanceService: services.investorCashBalanceService,
                paymentService: services.paymentService,
                settlementAPIService: services.settlementAPIService,
                configurationService: services.configurationService
            )
            return Snapshot(
                entries: snapshot.entries,
                openingBalance: snapshot.openingBalance,
                closingBalance: snapshot.closingBalance,
                timelineTruncated: false
            )
        case .trader:
            let snapshot = await TraderAccountStatementBuilder.buildSnapshotWithWallet(
                for: user,
                invoiceService: services.invoiceService,
                configurationService: services.configurationService,
                paymentService: services.paymentService,
                settlementAPIService: services.settlementAPIService
            )
            return Snapshot(
                entries: snapshot.entries,
                openingBalance: snapshot.openingBalance,
                closingBalance: snapshot.closingBalance,
                timelineTruncated: snapshot.timelineTruncated
            )
        default:
            return Snapshot(entries: [], openingBalance: 0, closingBalance: 0, timelineTruncated: false)
        }
    }

    static func monthlyStatementExists(
        year: Int,
        month: Int,
        role: UserRole,
        in documents: [Document],
        user: User
    ) -> Bool {
        let keys = DocumentInboxPolicy.documentInboxUserIdKeys(for: user)
        return documents.contains { doc in
            doc.type == .monthlyAccountStatement
                && doc.statementYear == year
                && doc.statementMonth == month
                && doc.statementRole == role
                && DocumentInboxPolicy.belongsToUser(doc, keys: keys)
        }
    }
}
