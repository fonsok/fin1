import Foundation

extension Document {
    /// Ensures a cached inbox row matches the statement line's Beleg reference (id + number).
    func matchesBelegReference(for entry: AccountStatementEntry) -> Bool {
        let expectedId = entry.referenceDocumentId ?? entry.metadata["referenceDocumentId"]
        if let expectedId, !expectedId.isEmpty, self.id != expectedId {
            return false
        }
        let expectedNumber = entry.referenceDocumentNumber ?? entry.metadata["referenceDocumentNumber"]
        if let expectedNumber, !expectedNumber.isEmpty {
            return self.accountingDocumentNumber == expectedNumber
        }
        return true
    }
}

extension AccountStatementEntry {
    /// Resolves the `Document` row for a statement line that carries a Beleg reference.
    /// 1. Direct id (`referenceDocumentId`) – matches Document.objectId.
    /// 2. Direct accounting number (`referenceDocumentNumber`).
    /// 3. Investor settlement: `investorCollectionBill` by `investmentId` + `tradeId`.
    /// 4. Trader trade settlement: `traderCollectionBill` by `tradeId` + buy/sell direction.
    func referencedDocument(documentService: any DocumentServiceProtocol) -> Document? {
        if self.prefersInvestorCollectionBill,
           let investorBill = investorCollectionBillFallback(documentService: documentService) {
            return investorBill
        }

        let docId = referenceDocumentId ?? metadata["referenceDocumentId"]
        if let docId, !docId.isEmpty,
           let byId = documentService.getDocument(by: docId) {
            if byId.type == .investorCollectionBill || !self.prefersInvestorCollectionBill {
                return byId
            }
        }

        let docNumber = referenceDocumentNumber ?? metadata["referenceDocumentNumber"]
        if let docNumber, !docNumber.isEmpty {
            let matches = documentService.documents.filter { $0.accountingDocumentNumber == docNumber }
            if let investorMatch = matches.first(where: { $0.type == .investorCollectionBill }) {
                return investorMatch
            }
            if let any = matches.first {
                return any
            }
        }

        if category == .tradeSettlement,
           !self.hasExplicitBelegReference,
           let tradeId = metadata["tradeId"], !tradeId.isEmpty,
           let txType = metadata["transactionType"], !txType.isEmpty {
            let candidates = documentService.documents
                .filter { $0.tradeId == tradeId && $0.type == .traderCollectionBill }
            let prefix = txType == "buy" ? "Kauf" : "Verkauf"
            return candidates.first(where: { $0.name.lowercased().hasPrefix(prefix.lowercased()) })
                ?? candidates.first
        }

        return nil
    }

    /// Robust resolver: same fallback chain as `referencedDocument`, but if the local
    /// `documentService.documents` cache misses (race / partial fetch / role-specific
    /// `Document` types not yet pulled into the trader DocumentService), fall back to a
    /// direct Parse fetch by `referenceDocumentId`. Used by the AccountStatement tap
    /// handler so Belegnr.-Links don't silently fail when the data exists server-side.
    @MainActor
    func resolveReferencedDocument(documentService: any DocumentServiceProtocol) async -> Document? {
        if let cached = referencedDocument(documentService: documentService),
           cached.matchesBelegReference(for: self) {
            if !cached.needsTraderBelegSnapshotRefresh {
                return cached
            }
        }

        let docId = referenceDocumentId ?? metadata["referenceDocumentId"]
        if let docId, !docId.isEmpty {
            do {
                let fetched = try await documentService.resolveDocumentForDeepLink(objectId: docId)
                if fetched.matchesBelegReference(for: self),
                   fetched.type == .investorCollectionBill || !self.prefersInvestorCollectionBill {
                    return fetched
                }
            } catch {
                print("⚠️ AccountStatementEntry: resolveDocumentForDeepLink failed for \(docId): \(error.localizedDescription)")
            }
        }

        return self.investorCollectionBillFallback(documentService: documentService)
    }

    private var hasExplicitBelegReference: Bool {
        let docNumber = referenceDocumentNumber ?? metadata["referenceDocumentNumber"]
        if let docNumber, !docNumber.isEmpty { return true }
        let docId = referenceDocumentId ?? metadata["referenceDocumentId"]
        if let docId, !docId.isEmpty { return true }
        return false
    }

    private var prefersInvestorCollectionBill: Bool {
        let backendType = metadata["backendEntryType"] ?? ""
        if backendType == "residual_return" { return false }
        if backendType == "investment_return" { return true }
        if category == .commission { return true }
        if category == .investment && direction == .credit && backendType.isEmpty {
            return true
        }
        return false
    }

    private func investorCollectionBillFallback(documentService: any DocumentServiceProtocol) -> Document? {
        guard self.prefersInvestorCollectionBill else { return nil }
        guard let investmentId = metadata["investmentId"], !investmentId.isEmpty,
              let tradeId = metadata["tradeId"], !tradeId.isEmpty else {
            return nil
        }
        return documentService.documents.first {
            $0.type == .investorCollectionBill
                && $0.investmentId == investmentId
                && $0.tradeId == tradeId
        }
    }
}
