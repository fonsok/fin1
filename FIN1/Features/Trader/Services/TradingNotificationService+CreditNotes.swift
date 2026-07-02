import Foundation

extension TradingNotificationService {
    func generateCreditNoteDocument(for trade: Trade, commissionAmount: Double, grossProfit: Double) async {
        guard commissionAmount > 0 else {
            print("📄 CreditNote: No commission to document (amount: €\(commissionAmount))")
            return
        }

        let documentId = self.transactionIdService.generateInvoiceNumber()
        print("📄 Credit Note Generated: \(documentId) for Trade #\(trade.tradeNumber)")

        let customerInfo = CustomerInfo(
            name: userService.currentUser?.displayName ?? "Dr. Hans-Peter Müller",
            address: "Hauptstraße 42",
            city: "Frankfurt am Main",
            postalCode: "60311",
            taxNumber: "43/123/45678",
            depotNumber: "DE12345678901234567890",
            bank: "Deutsche Bank AG",
            customerNumber: trade.traderId
        )

        let creditNoteInvoice = Invoice.creditNote(
            totalCommissionAmount: commissionAmount,
            customerInfo: customerInfo,
            transactionIdService: self.transactionIdService,
            tradeNumbers: [trade.tradeNumber],
            commissions: [],
            traderCommissionRateSnapshot: self.configurationService.effectiveCommissionRate
        )

        let documentName = "Gutschrift \(TradeNumberFormatting.labeled(number: trade.tradeNumber, year: trade.resolvedTradeNumberYear))"
        let recipientId = trade.traderId

        let document = Document(
            userId: recipientId,
            name: documentName,
            type: .traderCreditNote,
            status: .verified,
            fileURL: "creditnote://\(documentId).pdf",
            size: 1_024 * 45,
            uploadedAt: Date(),
            invoiceData: creditNoteInvoice,
            tradeId: trade.id,
            tradeNumber: trade.tradeNumber,
            documentNumber: creditNoteInvoice.invoiceNumber,
            traderCommissionRateSnapshot: creditNoteInvoice.traderCommissionRateSnapshot
        )

        do {
            try await self.documentService.uploadDocument(document)
            print("📄 Credit Note document added to notifications")
            print("   💰 Commission Amount: €\(String(format: "%.2f", commissionAmount))")
            print("   📊 Gross Profit: €\(String(format: "%.2f", grossProfit))")
        } catch {
            print("❌ Failed to add Credit Note document: \(error)")
        }

        await self.invoiceService.addInvoice(creditNoteInvoice)
        print("🔔 Notification: Credit Note \(documentId) is ready for download")
    }
}
