import Foundation

@MainActor
extension InvestmentsViewModel {
    // MARK: - Open Investment Lists

    /// Returns investments filtered by active status.
    var activeInvestments: [Investment] {
        investments.filter { $0.status == .active }
    }

    /// Returns investment rows for open (reserved + active) investments.
    /// Sorted by: creation date (newest first), then trader name (A-Z), then investment number (ascending).
    var openInvestmentRows: [InvestmentRow] {
        let baseRows = dataProcessor.processOpenInvestmentRows(from: self.activeInvestments)
        let userId = userService.currentUser?.id ?? ""
        return baseRows.map { row in
            let docs = documentService.getDocumentsForInvestment(row.investmentId)
            let docNumber = docs.first { $0.type == .investorCollectionBill }?.accountingDocumentNumber
            let batchId = row.investment.batchId ?? ""
            let invoiceNumber = batchId.isEmpty
                ? nil
                : invoiceService.getServiceChargeInvoiceForBatch(batchId, userId: userId)?.invoiceNumber
            return InvestmentRow(
                id: row.id,
                investmentId: row.investmentId,
                investmentNumber: row.investmentNumber,
                traderName: row.traderName,
                sequenceNumber: row.sequenceNumber,
                status: row.status,
                amount: row.amount,
                profit: row.profit,
                returnPercentage: row.returnPercentage,
                reservation: row.reservation,
                investment: row.investment,
                docNumber: docNumber,
                invoiceNumber: invoiceNumber
            )
        }
    }

    var totalOpenAmount: Double {
        dataProcessor.calculateTotalOpenAmount(from: self.openInvestmentRows)
    }

    var totalOpenProfit: Double? {
        dataProcessor.calculateTotalOpenProfit(from: self.openInvestmentRows)
    }

    var totalOpenReturn: Double? {
        dataProcessor.calculateTotalOpenReturn(from: self.openInvestmentRows, totalAmount: self.totalOpenAmount)
    }

    var reservedInvestmentRows: [InvestmentRow] {
        self.openInvestmentRows.filter(\.isDeletable)
    }

    var activeInvestmentRows: [InvestmentRow] {
        self.openInvestmentRows.filter { !$0.isDeletable }
    }

    var partialSellActiveInvestmentRows: [InvestmentRow] {
        self.activeInvestmentRows.filter { $0.investment.hasPartialSellRealization }
    }

    var totalReservedAmount: Double {
        dataProcessor.calculateTotalOpenAmount(from: self.reservedInvestmentRows)
    }

    var totalActiveAmount: Double {
        dataProcessor.calculateTotalOpenAmount(from: self.activeInvestmentRows)
    }

    var totalReservedProfit: Double? {
        dataProcessor.calculateTotalOpenProfit(from: self.reservedInvestmentRows)
    }

    var totalActiveProfit: Double? {
        dataProcessor.calculateTotalOpenProfit(from: self.activeInvestmentRows)
    }

    var totalReservedReturn: Double? {
        dataProcessor.calculateTotalOpenReturn(from: self.reservedInvestmentRows, totalAmount: self.totalReservedAmount)
    }

    var totalActiveReturn: Double? {
        dataProcessor.calculateTotalOpenReturn(from: self.activeInvestmentRows, totalAmount: self.totalActiveAmount)
    }

    // MARK: - Grouping for View Display

    var groupedOpenInvestments: [String: [InvestmentRow]] {
        dataProcessor.groupOpenInvestments(self.openInvestmentRows)
    }

    var groupedReservedInvestments: [String: [InvestmentRow]] {
        dataProcessor.groupOpenInvestments(self.reservedInvestmentRows)
    }

    var groupedActiveInvestments: [String: [InvestmentRow]] {
        dataProcessor.groupOpenInvestments(self.activeInvestmentRows)
    }

    var groupedPartialSellActiveInvestments: [String: [InvestmentRow]] {
        dataProcessor.groupOpenInvestments(self.partialSellActiveInvestmentRows)
    }

    var sortedTraderNames: [String] {
        dataProcessor.sortedTraderNames(from: self.groupedOpenInvestments)
    }

    var sortedReservedTraderNames: [String] {
        dataProcessor.sortedTraderNames(from: self.groupedReservedInvestments)
    }

    var sortedActiveTraderNames: [String] {
        dataProcessor.sortedTraderNames(from: self.groupedActiveInvestments)
    }

    var sortedPartialSellTraderNames: [String] {
        dataProcessor.sortedTraderNames(from: self.groupedPartialSellActiveInvestments)
    }
}
