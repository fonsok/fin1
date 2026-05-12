import Foundation

@MainActor
extension CollectionBillDocumentViewModel {
    /// Document row used for routing (merged with local store when available).
    var routingDocument: Document {
        canonicalDocument ?? document
    }

    /// Align notification/deep-link payloads with the same enrichment path as account-statement `referencedDocument` (id, then Belegnummer in local store).
    func mergeCanonicalCollectionBillPayload(_ payload: Document) -> Document {
        let byId = documentService.getDocument(by: payload.id) ?? payload
        if documentHasResolvableIds(byId) { return byId }

        let acc = (byId.accountingDocumentNumber ?? payload.accountingDocumentNumber)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !acc.isEmpty,
           let richer = documentService.documents.first(where: { row in
               (row.accountingDocumentNumber ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == acc
                   && documentHasResolvableIds(row)
           }) {
            return richer
        }
        return byId
    }

    func documentHasResolvableIds(_ doc: Document) -> Bool {
        if let t = doc.tradeId?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty { return true }
        if let i = doc.investmentId?.trimmingCharacters(in: .whitespacesAndNewlines), !i.isEmpty { return true }
        return false
    }

    func collectionBillPreloadUserIds() -> [String] {
        let doc = canonicalDocument ?? document
        var ids: [String] = []
        func append(_ value: String?) {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
            if !ids.contains(value) { ids.append(value) }
        }
        append(doc.userId)
        append(userService.currentUser?.id)
        if let email = userService.currentUser?.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !email.isEmpty {
            append("user:\(email)")
        }
        return ids
    }

    func preloadInvoicesAndInvestmentsForCollectionBill() async {
        let docType = routingDocument.type
        let userIds = collectionBillPreloadUserIds()
        for uid in userIds {
            do {
                try await invoiceService.loadInvoices(for: uid)
            } catch {
                print("⚠️ CollectionBillDocumentViewModel: loadInvoices(\(uid)) failed: \(error.localizedDescription)")
            }
        }
        if docType == .investorCollectionBill {
            for uid in userIds {
                await investmentService.fetchFromBackend(for: uid)
            }
        }
    }

    /// Debug: Documents/Notifications vs account-statement (Xcode console filter: `CollectionBillDocumentView —`).
    func logCollectionBillHydration(label: String, payload: Document, merged: Document) {
        let tradeId = merged.tradeId ?? "nil"
        let invId = merged.investmentId ?? "nil"
        let acc = merged.accountingDocumentNumber ?? "nil"
        let tradeHits = merged.tradeId.map { invoiceService.getInvoicesForTrade($0) } ?? []
        let tradeInvoiceLines = tradeHits.enumerated().map { idx, inv in
            "      [\(idx)] id=\(inv.id) invoiceNumber=\(inv.invoiceNumber) type=\(inv.type.rawValue) tradeId=\(inv.tradeId ?? "nil")"
        }

        print("""
            🔎 CollectionBillDocumentView — \(label)
              payload.id=\(payload.id) merged.id=\(merged.id)
              payload.name=\(payload.name)
              merged.userId=\(merged.userId)
              merged.tradeId=\(tradeId) merged.investmentId=\(invId)
              merged.accountingDocumentNumber=\(acc)
              documentService.documents.count=\(documentService.documents.count)
              invoices.count=\(invoiceService.invoices.count)
              getInvoicesForTrade(\(tradeId)): count=\(tradeHits.count)
            \(tradeInvoiceLines.isEmpty ? "      (no trade invoices)" : tradeInvoiceLines.joined(separator: "\n"))
            """)
    }

    func loadTargetFromDocument() async {
        resolvedFullTrade = nil
        canonicalDocument = mergeCanonicalCollectionBillPayload(document)
        logCollectionBillHydration(label: "after mergeCanonical", payload: document, merged: routingDocument)

        await preloadInvoicesAndInvestmentsForCollectionBill()

        let invoiceCountAfter = invoiceService.invoices.count
        logCollectionBillHydration(
            label: "after preload (invoices.count=\(invoiceCountAfter))",
            payload: document,
            merged: routingDocument
        )

        print("🔍 CollectionBillDocumentViewModel: Loading target from document '\(routingDocument.name)'")

        var resolved = false

        switch routingDocument.type {
        case .traderCollectionBill:
            resolved = await resolveTradeTarget()
        case .investorCollectionBill:
            resolved = await resolveInvestmentTarget()
            if !resolved {
                await generateInvestorPreviewFallback()
                return
            }
        default:
            resolved = false
        }

        if !resolved {
            print("❌ CollectionBillDocumentViewModel: Failed to resolve document target for '\(routingDocument.name)'")
            errorMessage = "Could not extract trade or investment information from document metadata"
            fallbackToDocumentViewer = true
            isLoading = false
        }
    }

    func generateInvestorPreviewFallback() async {
        let doc = routingDocument
        print("ℹ️ CollectionBillDocumentViewModel: Generating investor preview fallback for '\(doc.name)'")
        let previewImage = InvestorCollectionBillPDFGenerator.generatePreviewImage(for: doc)
        let pdfData = InvestorCollectionBillPDFGenerator.generatePDFData(for: doc)

        investorPreviewImage = previewImage
        investorPDFData = pdfData
        isLoading = false
    }
}
