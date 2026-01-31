import Foundation

// MARK: - Monthly Account Statement Generator
/// Generates calendar-month account statement documents for investors and traders.
struct MonthlyAccountStatementGenerator {
    /// Generates statements for all completed months (excluding the current, possibly incomplete month).
    static func ensureMonthlyStatements(for user: User, services: AppServices) async {
        // Build full statement entries for the user
        let entries: [AccountStatementEntry]
        switch user.role {
        case .investor:
            let ledger = services.investorCashBalanceService.getTransactions(for: user.id)
            entries = ledger
        case .trader:
            let snapshot = TraderAccountStatementBuilder.buildSnapshot(
                for: user,
                invoiceService: services.invoiceService,
                configurationService: services.configurationService
            )
            entries = snapshot.entries
        default:
            return
        }

        guard !entries.isEmpty else { return }

        let calendar = Calendar.current
        let now = Date()
        let currentComponents = calendar.dateComponents([.year, .month], from: now)

        // Group entries by (year, month), excluding current (possibly incomplete) month
        var monthSet = Set<String>() // "year-month" key
        for entry in entries {
            let comps = calendar.dateComponents([.year, .month], from: entry.occurredAt)
            guard let year = comps.year, let month = comps.month else { continue }

            if year == currentComponents.year, month == currentComponents.month {
                continue // Skip current month; statement is generated after month-end
            }

            let key = "\(year)-\(month)"
            monthSet.insert(key)
        }

        guard !monthSet.isEmpty else { return }

        let existingDocs = services.documentService.getDocuments(for: user.id)

        for key in monthSet {
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let year = Int(parts[0]),
                  let month = Int(parts[1]) else { continue }

            // Skip if statement for this month already exists
            let alreadyExists = existingDocs.contains {
                $0.type == .monthlyAccountStatement &&
                $0.statementYear == year &&
                $0.statementMonth == month &&
                $0.statementRole == user.role
            }

            if alreadyExists {
                continue
            }

            // Only create statement if there are entries in that month
            let monthEntries = entries.filter { entry in
                let comps = calendar.dateComponents([.year, .month], from: entry.occurredAt)
                return comps.year == year && comps.month == month
            }

            guard !monthEntries.isEmpty else { continue }

            let name = DocumentNamingUtility.monthlyAccountStatementName(for: user, year: year, month: month)
            let dummyFileURL = "monthly-statement://\(user.id)/\(year)-\(month)"

            let document = Document(
                userId: user.id,
                name: name,
                type: .monthlyAccountStatement,
                status: .verified,
                fileURL: dummyFileURL,
                size: 1024, // Non-zero placeholder for validation
                uploadedAt: Date(),
                verifiedAt: Date(),
                expiresAt: nil,
                invoiceData: nil,
                tradeId: nil,
                investmentId: nil,
                statementYear: year,
                statementMonth: month,
                statementRole: user.role
            )

            guard services.documentService.validateDocument(document) else {
                continue
            }

            // Store document
            try? await services.documentService.uploadDocument(document)

            // Notify user about new statement
            let monthNameFormatter = DateFormatter()
            monthNameFormatter.locale = Locale.current
            monthNameFormatter.dateFormat = "LLLL yyyy"
            let dateForTitle = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
            let monthTitle = monthNameFormatter.string(from: dateForTitle)

            services.notificationService.createNotification(
                title: "New monthly account statement",
                message: "Your account statement for \(monthTitle) is now available.",
                type: .document,
                priority: .medium,
                for: user.id,
                metadata: nil
            )
        }
    }

    /// Creates a mock monthly account statement document for the **current calendar month**
    /// using the user's current transactions. Intended for manual generation from the
    /// Account Statement screen (e.g., for traders).
    static func createMockCurrentMonthStatement(for user: User, services: AppServices) async {
        let calendar = Calendar.current
        let now = Date()
        let comps = calendar.dateComponents([.year, .month], from: now)
        guard let year = comps.year, let month = comps.month else { return }

        // Build full statement entries for the user
        let entries: [AccountStatementEntry]
        switch user.role {
        case .investor:
            entries = services.investorCashBalanceService.getTransactions(for: user.id)
        case .trader:
            let snapshot = TraderAccountStatementBuilder.buildSnapshot(
                for: user,
                invoiceService: services.invoiceService,
                configurationService: services.configurationService
            )
            entries = snapshot.entries
        default:
            return
        }

        guard !entries.isEmpty else { return }

        // Filter to current month
        let monthEntries = entries.filter { entry in
            let ec = calendar.dateComponents([.year, .month], from: entry.occurredAt)
            return ec.year == year && ec.month == month
        }

        guard !monthEntries.isEmpty else { return }

        let name = DocumentNamingUtility.monthlyAccountStatementName(for: user, year: year, month: month)
        let dummyFileURL = "monthly-statement://\(user.id)/\(year)-\(month)/mock"

        let document = Document(
            userId: user.id,
            name: name,
            type: .monthlyAccountStatement,
            status: .verified,
            fileURL: dummyFileURL,
            size: 1024,
            uploadedAt: Date(),
            verifiedAt: Date(),
            expiresAt: nil,
            invoiceData: nil,
            tradeId: nil,
            investmentId: nil,
            statementYear: year,
            statementMonth: month,
            statementRole: user.role
        )

        guard services.documentService.validateDocument(document) else {
            return
        }

        try? await services.documentService.uploadDocument(document)

        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale.current
        monthFormatter.dateFormat = "LLLL yyyy"
        let dateForTitle = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? now
        let monthTitle = monthFormatter.string(from: dateForTitle)

        services.notificationService.createNotification(
            title: "Mock monthly account statement created",
            message: "A mock account statement for \(monthTitle) has been generated from current transactions.",
            type: .document,
            priority: .low,
            for: user.id,
            metadata: nil
        )
    }
}
