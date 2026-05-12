import Foundation

@MainActor
extension CollectionBillDocumentViewModel {
    func resolveInvestmentTarget() async -> Bool {
        let doc = routingDocument
        if let investmentId = doc.investmentId {
            return await loadInvestment(withId: investmentId)
        }

        if let parsedId = extractInvestmentIdFromDocumentName(doc.name) {
            return await loadInvestment(withId: parsedId)
        }

        if let batchPrefix = extractBatchIdPrefixFromInvestorCollectionBillName(doc.name),
           await loadInvestment(byBatchIdPrefix: batchPrefix) {
            return true
        }

        print("❌ CollectionBillDocumentViewModel: Unable to resolve investment id for document '\(doc.name)'")
        return false
    }

    func loadInvestment(withId investmentId: String) async -> Bool {
        let doc = routingDocument
        print("🔍 CollectionBillDocumentViewModel: Resolving investment '\(investmentId)' for user '\(doc.userId)'")

        let investorInvestments = investmentService.getInvestments(for: doc.userId)
        let allInvestments = investmentService.investments

        let resolvedInvestment = investorInvestments.first(where: { $0.id == investmentId }) ??
            allInvestments.first(where: { $0.id == investmentId }) ??
            allInvestments.first(where: { $0.batchId == investmentId })

        guard let foundInvestment = resolvedInvestment else {
            if let backendInvestment = await fetchInvestmentFromBackend(investmentId: investmentId) {
                print("✅ Loaded investment '\(investmentId)' from backend fallback")
                investment = backendInvestment
                isLoading = false
                return true
            }

            print("❌ Investment '\(investmentId)' not found for user '\(doc.userId)'")
            errorMessage = "Investment \(investmentId) not found"
            isLoading = false
            return false
        }

        print("✅ Found investment: ID=\(foundInvestment.id), Investor=\(foundInvestment.investorId)")
        investment = foundInvestment
        isLoading = false
        return true
    }

    /// Resolves investments from batch pool bill filenames (`InvestorCollectionBill_Batch{first8OfBatchId}_…`).
    func loadInvestment(byBatchIdPrefix prefixRaw: String) async -> Bool {
        let prefix = prefixRaw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard prefix.count >= 6 else { return false }

        func batchMatches(_ batchId: String?) -> Bool {
            guard let batchId, !batchId.isEmpty else { return false }
            let upper = batchId.uppercased()
            let compact = upper.replacingOccurrences(of: "-", with: "")
            return compact.hasPrefix(prefix) || upper.hasPrefix(prefix)
        }

        let doc = routingDocument
        var byId: [String: Investment] = [:]
        for inv in investmentService.getInvestments(for: doc.userId) {
            byId[inv.id] = inv
        }
        for inv in investmentService.investments {
            byId[inv.id] = inv
        }

        if let found = byId.values.first(where: { batchMatches($0.batchId) }) {
            print("✅ CollectionBillDocumentView: Matched investment by batch prefix \(prefix): id=\(found.id) batchId=\(found.batchId ?? "")")
            investment = found
            isLoading = false
            return true
        }

        guard let parseAPIClient else { return false }

        for investorKey in collectionBillPreloadUserIds() {
            do {
                let rows: [ParseInvestment] = try await parseAPIClient.fetchObjects(
                    className: "Investment",
                    query: ["investorId": investorKey],
                    include: nil,
                    orderBy: "-updatedAt",
                    limit: 200
                )
                if let foundRow = rows.first(where: { batchMatches($0.batchId) }) {
                    let found = foundRow.toInvestment()
                    print("✅ CollectionBillDocumentView: Matched investment by batch prefix \(prefix) (Parse): id=\(found.id)")
                    investment = found
                    isLoading = false
                    return true
                }
            } catch {
                print("ℹ️ CollectionBillDocumentViewModel: batch-prefix Investment fetch failed for \(investorKey): \(error.localizedDescription)")
            }
        }

        return false
    }

    func fetchInvestmentFromBackend(investmentId: String) async -> Investment? {
        guard let parseAPIClient else { return nil }

        do {
            let parsed: ParseInvestment = try await parseAPIClient.fetchObject(
                className: "Investment",
                objectId: investmentId,
                include: nil
            )
            return parsed.toInvestment()
        } catch {
            print("ℹ️ CollectionBillDocumentViewModel: direct backend lookup failed for '\(investmentId)': \(error.localizedDescription)")
        }

        do {
            let parsed: [ParseInvestment] = try await parseAPIClient.fetchObjects(
                className: "Investment",
                query: ["batchId": investmentId],
                include: nil,
                orderBy: "-createdAt",
                limit: 1
            )
            return parsed.first?.toInvestment()
        } catch {
            print("ℹ️ CollectionBillDocumentViewModel: batchId backend lookup failed for '\(investmentId)': \(error.localizedDescription)")
            return nil
        }
    }

    func extractInvestmentIdFromDocumentName(_ name: String) -> String? {
        let pattern = #"Investment([^_]+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let range = Range(match.range(at: 1), in: name) {
            return String(name[range])
        }
        return nil
    }

    /// First segment of batch UUID embedded in `InvestorCollectionBill_Batch606B2CEF_…`.
    func extractBatchIdPrefixFromInvestorCollectionBillName(_ name: String) -> String? {
        let pattern = #"InvestorCollectionBill_Batch([A-Za-z0-9]+)_"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let range = Range(match.range(at: 1), in: name) {
            return String(name[range])
        }
        return nil
    }
}
