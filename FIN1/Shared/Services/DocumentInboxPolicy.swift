import Foundation

/// Shared rules for Profile → Notifications → Documents (iOS + parity with `getUserDocumentInbox`).
enum DocumentInboxPolicy {

    /// Page size for `getUserDocumentInbox` (server cap 200).
    static let inboxPageSize = 100

    /// Max additional pages after the first (100 + 2×100 = 300 documents cap).
    static let inboxMaxExtraPages = 2

    /// Types primarily authored on the server; inbox refresh treats the API as SSOT for these rows.
    static let serverManagedTypes: Set<DocumentType> = [
        .traderCollectionBill,
        .traderCreditNote,
        .investorCollectionBill,
        .invoice,
        .other, // trade_execution_document maps here when unknown
    ]

    static func documentInboxUserIdKeys(for user: User) -> Set<String> {
        var keys = Set(user.ledgerUserIdCandidates)
        let email = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !email.isEmpty {
            keys.insert(UserFactory.stableUserId(for: email))
        }
        return keys
    }

    static func belongsToUser(_ document: Document, keys: Set<String>) -> Bool {
        let uid = document.userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return false }
        if keys.contains(uid) { return true }

        let lowerUid = uid.lowercased()
        for key in keys {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed.lowercased() == lowerUid { return true }
            if trimmed.hasPrefix("user:") {
                let email = String(trimmed.dropFirst(5)).lowercased()
                if lowerUid == trimmed.lowercased() || lowerUid == email { return true }
            } else if trimmed.contains("@"), lowerUid == "user:\(trimmed.lowercased())" {
                return true
            }
        }

        // Backend settlement rows use Parse objectId on `Document.userId`; inbox keys may
        // still carry legacy `user:email` until getUserMe/login overlay completes.
        if self.isParseObjectId(uid) {
            for key in keys where self.isParseObjectId(key) {
                if key == uid { return true }
            }
        }
        return false
    }

    /// Parse `objectId` (10-char alphanumeric).
    static func isParseObjectId(_ value: String) -> Bool {
        value.range(of: #"^[a-zA-Z0-9]{10}$"#, options: .regularExpression) != nil
    }

    /// Parse `Document.type` values that are GoB-internal (not customer-facing inbox).
    static let internalBackendDocumentTypes: Set<String> = [
        "investmentReservationEigenbeleg",
        "poolMirrorExecutionEigenbeleg",
        "investorPartialSellInternal",
    ]

    /// Accounting prefixes for internal eigenbelege (pool mirror PMBC/PMSC, fees TFS, partial-sell EBP).
    static let internalInboxAccountingPrefixes = ["PMBC-", "PMSC-", "PME-", "TFS-", "EBP-"]

    static func isInternalBackendDocumentType(_ rawType: String) -> Bool {
        self.internalBackendDocumentTypes.contains(rawType.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// GoB-internal belege belong in App-Ledger / admin reports, not Profile → Notifications → Documents.
    static func isInternalInboxDocument(_ document: Document) -> Bool {
        if document.type == .investmentReservationEigenbeleg {
            return true
        }
        let accNo = (document.accountingDocumentNumber ?? document.documentNumber ?? "").uppercased()
        if self.internalInboxAccountingPrefixes.contains(where: { accNo.hasPrefix($0) }) {
            return true
        }
        let fileURL = document.fileURL.lowercased()
        if fileURL.hasPrefix("eigenbeleg-partial-sell://") {
            return true
        }
        let name = document.name.lowercased()
        if name.contains("eigenbeleg"),
           name.contains("pool") || name.contains("partialsell") || name.contains("partial_sell") {
            return true
        }
        if let summary = document.accountingSummaryText?.lowercased(),
           summary.contains("eigenbeleg"),
           summary.contains("intern") {
            return true
        }
        return false
    }

    /// Trader-only / investor-only settlement types must not cross roles in the notifications inbox.
    static func isDocumentTypeVisibleToRole(_ type: DocumentType, role: UserRole) -> Bool {
        switch role {
        case .investor:
            switch type {
            case .traderCollectionBill, .traderCreditNote:
                return false
            default:
                return true
            }
        case .trader:
            switch type {
            case .investorCollectionBill:
                return false
            default:
                return true
            }
        case .admin, .customerService, .other:
            return true
        }
    }

    /// Server inbox rows are session-scoped; show Parse-backed settlement belege even when
    /// `Document.userId` (objectId) and local `User.id` (legacy) are briefly out of sync.
    static func belongsToUserOrServerInboxRow(
        _ document: Document,
        keys: Set<String>,
        role: UserRole? = nil
    ) -> Bool {
        if self.belongsToUser(document, keys: keys) {
            if let role, !self.isDocumentTypeVisibleToRole(document.type, role: role) {
                return false
            }
            return true
        }
        guard self.isParseBackedDocumentId(document.id) else { return false }
        guard self.isServerManagedInboxType(document.type),
              !self.isLocalPlaceholderDocument(document) else { return false }
        if let role, !self.isDocumentTypeVisibleToRole(document.type, role: role) {
            return false
        }
        return true
    }

    /// SSOT scope for Notifications inbox list + unread badge (notifications + documents).
    static func inboxDocuments(from documents: [Document], for user: User) -> [Document] {
        let keys = self.documentInboxUserIdKeys(for: user)
        return documents
            .filter { self.belongsToUserOrServerInboxRow($0, keys: keys, role: user.role) }
            .filter { self.isDisplayableInNotificationsInbox($0) }
    }

    static func notificationBelongsToInbox(_ notification: AppNotification, keys: Set<String>) -> Bool {
        keys.contains(notification.userId)
    }

    /// Parse `objectId` (10-char alphanumeric), not local placeholder ids.
    static func isParseBackedDocumentId(_ id: String) -> Bool {
        id.range(of: #"^[a-zA-Z0-9]{10}$"#, options: .regularExpression) != nil
    }

    static func isServerManagedInboxType(_ type: DocumentType) -> Bool {
        self.serverManagedTypes.contains(type)
    }

    /// Mirrors backend/iOS inbox filter (wallet receipts, eigenbeleg, …).
    /// Local-only rows created before backend settlement (placeholder URLs, no Parse id yet).
    static func isLocalPlaceholderDocument(_ document: Document) -> Bool {
        if self.isParseBackedDocumentId(document.id),
           document.hasAccountingDocumentNumber,
           self.isServerManagedInboxType(document.type) {
            return false
        }
        let url = document.fileURL.lowercased()
        return url.hasPrefix("creditnote://")
            || url.hasPrefix("collectionbill://")
            || url.hasPrefix("investment://")
            || url.hasPrefix("invoice://")
    }

    /// Server-owned beleg types must not be written to Parse from the client (no `metadata.returnPercentage`, etc.).
    /// Local placeholder rows stay in the on-device inbox until `getUserDocumentInbox` returns the backend bill.
    static func shouldSyncDocumentToParse(_ document: Document) -> Bool {
        if self.isServerManagedInboxType(document.type), self.isLocalPlaceholderDocument(document) {
            return false
        }
        return true
    }

    /// Title for Notifications → Documents (prefer accounting number CB-/CN- over storage filename).
    static func inboxTitle(for document: Document) -> String {
        if let number = document.accountingDocumentNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
           !number.isEmpty {
            return number
        }
        if let number = document.documentNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
           !number.isEmpty,
           number.contains("-") {
            return number
        }
        return document.name
    }

    /// Prefer server settlement row over pre-backend local placeholder for the same trade + type.
    static func shouldPreferOverLocalPlaceholder(_ candidate: Document, existing: Document) -> Bool {
        guard self.isLocalPlaceholderDocument(existing) else { return false }
        guard !self.isLocalPlaceholderDocument(candidate) else { return false }
        guard candidate.type == existing.type else { return false }
        guard let tradeId = existing.tradeId, !tradeId.isEmpty else { return false }
        return candidate.tradeId == tradeId
    }

    /// Drops local `creditnote://` / `collectionbill://` rows when a Parse-backed row exists for the same trade.
    static func dedupeInboxDocuments(_ documents: [Document]) -> [Document] {
        let byId = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })
        let list = Array(byId.values)
        return list.filter { doc in
            guard self.isLocalPlaceholderDocument(doc) else { return true }
            let hasServerTwin = list.contains { self.shouldPreferOverLocalPlaceholder($0, existing: doc) }
            return !hasServerTwin
        }
    }

    static func isDisplayableInNotificationsInbox(_ document: Document) -> Bool {
        if self.isInternalInboxDocument(document) {
            return false
        }
        if document.type == .financial {
            let accNo = (document.accountingDocumentNumber ?? "").uppercased()
            if accNo.hasPrefix("IAR-") || accNo.hasPrefix("IRR-") || accNo.hasPrefix("IFR-") {
                return false
            }
            if document.name.lowercased().hasPrefix("investorcollectionbill_") {
                return false
            }
        }
        return true
    }
}
