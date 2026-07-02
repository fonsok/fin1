import Foundation

extension TradingNotificationService {
    func generateInvoiceAndNotification(
        for order: Order,
        tradeId: String? = nil,
        tradeNumber: Int? = nil,
        tradeNumberYear: Int? = nil
    ) async {
        if self.configurationService.blocksLocalInvoiceGeneration {
            print(
                "ℹ️ TradingNotificationService: skip client invoice — traderMonetaryServerOnly/frontendReadonlyMode active"
            )
            return
        }

        if let tradeId, !tradeId.isEmpty,
           self.documentService.documentExists(for: tradeId, ofType: .invoice) {
            print(
                "ℹ️ TradingNotificationService: skip client invoice — backend invoice already present for trade \(tradeId)"
            )
            return
        }

        let invoiceId = self.transactionIdService.generateInvoiceNumber()
        print("📄 Invoice Generated: \(invoiceId) for \(order.symbol) (Trade ID: \(tradeId ?? "none"))")

        let customerInfo = CustomerInfo(
            name: "Dr. Hans-Peter Müller",
            address: "Hauptstraße 42",
            city: "Frankfurt am Main",
            postalCode: "60311",
            taxNumber: "43/123/45678",
            depotNumber: "DE12345678901234567890",
            bank: "Deutsche Bank AG",
            customerNumber: order.traderId
        )

        let invoice: Invoice = InvoiceLocalSynthesisGate.withPermitted {
            if order.type == .buy {
                let orderBuy = OrderBuy(from: order)
                return Invoice.from(
                    order: orderBuy,
                    customerInfo: customerInfo,
                    transactionIdService: self.transactionIdService,
                    tradeId: tradeId,
                    tradeNumber: tradeNumber,
                    tradeNumberYear: tradeNumberYear
                )
            }
            let orderSell = OrderSell(from: order)
            return Invoice.from(
                sellOrder: orderSell,
                customerInfo: customerInfo,
                transactionIdService: self.transactionIdService,
                tradeId: tradeId,
                tradeNumber: tradeNumber,
                tradeNumberYear: tradeNumberYear
            )
        }

        let documentName = DocumentNamingUtility.invoiceName(for: invoice, userRole: .trader)
        let recipientId = order.traderId
        print(
            "📄 TradingNotificationService: Creating document with userId=\(recipientId), currentUser.id=\(self.userService.currentUser?.id ?? "nil"), order.traderId=\(order.traderId)"
        )
        let document = Document(
            userId: recipientId,
            name: documentName,
            type: .invoice,
            status: .verified,
            fileURL: "invoice://\(invoiceId).pdf",
            size: 1_024 * 50,
            uploadedAt: Date(),
            invoiceData: invoice,
            tradeId: tradeId,
            documentNumber: invoice.invoiceNumber
        )

        do {
            try await self.documentService.uploadDocument(document)
            print("📄 Invoice document added to notifications")
            print("   📊 DocumentService now has \(self.documentService.documents.count) documents")
            print("   🔔 NotificationService should observe this change and update count")
        } catch {
            print("❌ Failed to add invoice document: \(error)")
        }

        await self.invoiceService.addInvoice(invoice)
        print("📄 Invoice added to invoice service: \(invoice.formattedInvoiceNumber)")
        print("🔔 Notification: Invoice \(invoiceId) is ready for download")
    }
}
