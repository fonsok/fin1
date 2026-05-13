import Foundation

@MainActor
extension InvestmentsViewModel {
    // MARK: - Completed Investment Lists

    /// Returns investments filtered by completed/cancelled, plus partially-completed (active with completed status).
    /// Sorted by: completion date (newest first), then trader name (A-Z), then investment number.
    var completedInvestments: [Investment] {
        let fullyDone = investments.filter { $0.status == .completed || $0.status == .cancelled }
        let partials = investments.filter { inv in
            inv.status == .active && inv.reservationStatus == .completed
        }
        let completed = fullyDone + partials

        return completed.sorted { first, second in
            let firstDate = first.completedAt ?? first.updatedAt
            let secondDate = second.completedAt ?? second.updatedAt
            if firstDate != secondDate {
                return firstDate > secondDate
            }
            if first.traderName != second.traderName {
                return first.traderName < second.traderName
            }
            let firstNumber = dataProcessor.extractInvestmentNumber(from: first.id.extractInvestmentNumber())
            let secondNumber = dataProcessor.extractInvestmentNumber(from: second.id.extractInvestmentNumber())
            return firstNumber < secondNumber
        }
    }

    /// Returns completed/partial investments filtered by time period.
    var completedInvestmentsByTimePeriod: [Investment] {
        let allCompleted = self.completedInvestments
        let cutoffDate = selectedTimePeriod.cutoffDate()

        return allCompleted.filter { investment in
            if let completedAt = investment.completedAt {
                return completedAt >= cutoffDate
            }
            return true
        }
    }

    /// Beleg-/Rechnungsnummern für abgeschlossene Investments (MVVM: View bindet nur daran).
    var completedInvestmentDocRefs: [String: (docNumber: String?, invoiceNumber: String?)] {
        let userId = userService.currentUser?.id ?? ""
        var refs: [String: (docNumber: String?, invoiceNumber: String?)] = [:]
        for inv in self.completedInvestmentsByTimePeriod {
            let docs = documentService.getDocumentsForInvestment(inv.id)
            let docNumber = docs.first { $0.type == .investorCollectionBill }?.accountingDocumentNumber
            let batchId = inv.batchId ?? ""
            let invoiceNumber = batchId.isEmpty
                ? nil
                : invoiceService.getServiceChargeInvoiceForBatch(batchId, userId: userId)?.invoiceNumber
            refs[inv.id] = (docNumber, invoiceNumber)
        }
        return refs
    }

    /// Returns completed/partial investments filtered by year (partials have no completedAt -> included).
    /// Deprecated: Use completedInvestmentsByTimePeriod instead.
    var completedInvestmentsByYear: [Investment] {
        self.completedInvestmentsByTimePeriod
    }

    /// Available years for filtering completed investments.
    var availableYears: [Int] {
        let years = self.completedInvestments.compactMap { investment -> Int? in
            guard let completedAt = investment.completedAt else { return nil }
            return Calendar.current.component(.year, from: completedAt)
        }
        return Array(Set(years)).sorted(by: >)
    }

    /// Returns the current selected year, defaulting to current year if none selected.
    /// Deprecated: Kept for backward compatibility.
    var currentSelectedYear: Int {
        selectedYear ?? Calendar.current.component(.year, from: Date())
    }

    /// Filters completed investments by the selected time period.
    func filterCompletedInvestments(by period: InvestmentTimePeriod) {
        selectedTimePeriod = period
    }
}
