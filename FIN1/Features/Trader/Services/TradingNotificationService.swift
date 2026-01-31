import Foundation
import Combine

// MARK: - Trading Notification Service Implementation
/// Handles trading notifications, confirmations, and invoice generation
final class TradingNotificationService: TradingNotificationServiceProtocol, ServiceLifecycle {
    static let shared = TradingNotificationService()

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let documentService: any DocumentServiceProtocol
    private let invoiceService: any InvoiceServiceProtocol
    private let transactionIdService: any TransactionIdServiceProtocol
    private let userService: any UserServiceProtocol

    init(documentService: any DocumentServiceProtocol = DocumentService.shared,
         invoiceService: any InvoiceServiceProtocol = InvoiceService(),
         transactionIdService: any TransactionIdServiceProtocol = TransactionIdService(),
         userService: any UserServiceProtocol = UserService()) {
        self.documentService = documentService
        self.invoiceService = invoiceService
        self.transactionIdService = transactionIdService
        self.userService = userService
        // No initial data loading needed for notification service
    }

    // MARK: - ServiceLifecycle
    func start() {
        // Notification service doesn't need to load data on start
    }

    func stop() {
        // Clean up any ongoing operations
    }

    func reset() {
        errorMessage = nil
    }

    // MARK: - Trading Notifications

    func showBuyConfirmation(for trade: Trade) async {
        // Post notification for buy confirmation
        await MainActor.run {
            NotificationCenter.default.post(
                name: .buyOrderCompleted,
                object: trade
            )
        }
        print("✅ Buy Confirmation: \(trade.symbol) - \(trade.totalQuantity) shares at €\(trade.entryPrice) each")
    }

    func showSellConfirmation(for trade: Trade) async {
        // Post notification for sell confirmation
        await MainActor.run {
            NotificationCenter.default.post(
                name: .sellOrderCompleted,
                object: trade
            )
        }
        print("✅ Sell Confirmation: \(trade.symbol) - \(trade.totalQuantity) shares sold at €\(trade.exitPrice ?? 0) each")
    }

    func generateInvoiceAndNotification(for order: Order, tradeId: String? = nil, tradeNumber: Int? = nil) async {
        // Generate invoice with actual order values
        let invoiceId = transactionIdService.generateInvoiceNumber()
        print("📄 Invoice Generated: \(invoiceId) for \(order.symbol) (Trade ID: \(tradeId ?? "none"))")

        // CRITICAL: Use order.traderId as customer number for proper trader isolation
        // This ensures invoices are tied to the specific trader who placed the order
        let customerInfo = CustomerInfo(
            name: "Dr. Hans-Peter Müller",
            address: "Hauptstraße 42",
            city: "Frankfurt am Main",
            postalCode: "60311",
            taxNumber: "43/123/45678",
            depotNumber: "DE12345678901234567890",
            bank: "Deutsche Bank AG",
            customerNumber: order.traderId  // Use trader ID for proper isolation
        )

        // Create invoice from actual order data with trade ID and trade number
        let invoice: Invoice
        if order.type == .buy {
            let orderBuy = OrderBuy(from: order)
            invoice = Invoice.from(order: orderBuy, customerInfo: customerInfo, transactionIdService: transactionIdService, tradeId: tradeId, tradeNumber: tradeNumber)
        } else {
            let orderSell = OrderSell(from: order)
            invoice = Invoice.from(sellOrder: orderSell, customerInfo: customerInfo, transactionIdService: transactionIdService, tradeId: tradeId, tradeNumber: tradeNumber)
        }

        // Create document for the invoice with industry-standard naming
        let documentName = DocumentNamingUtility.invoiceName(for: invoice, userRole: .trader)
        // CRITICAL: Use order.traderId to ensure documents are associated with the order's owner
        // This ensures proper trade isolation between traders
        let recipientId = order.traderId
        print("📄 TradingNotificationService: Creating document with userId=\(recipientId), currentUser.id=\(userService.currentUser?.id ?? "nil"), order.traderId=\(order.traderId)")
        let document = Document(
            userId: recipientId,
            name: documentName,
            type: .invoice,
            status: .verified,
            fileURL: "invoice://\(invoiceId).pdf",
            size: 1024 * 50, // Mock 50KB PDF size
            uploadedAt: Date(),
            invoiceData: invoice,
            tradeId: tradeId,
            documentNumber: invoice.invoiceNumber
        )

        // Add document to document service
        do {
            try await documentService.uploadDocument(document)
            print("📄 Invoice document added to notifications")
            print("   📊 DocumentService now has \(documentService.documents.count) documents")
            print("   🔔 NotificationService should observe this change and update count")
        } catch {
            print("❌ Failed to add invoice document: \(error)")
        }

        // Add invoice to invoice service so it shows up in the UI
        await invoiceService.addInvoice(invoice)
        print("📄 Invoice added to invoice service: \(invoice.formattedInvoiceNumber)")

        // In a real app, this would save the invoice and send notification
        print("📄 Invoice Details:")
        print("   - Symbol: \(order.symbol)")
        print("   - Quantity: \(order.quantity)")
        print("   - Price: €\(order.price)")
        print("   - Total Amount: €\(order.totalAmount)")
        print("   - Order Fee: €\(max(5.0, min(50.0, order.totalAmount * 0.005)))")
        print("   - Exchange Fee: €\(max(1.0, min(20.0, order.totalAmount * 0.001)))")
        print("   - Foreign Costs: €1.50")

        // Send notification (in real app, this would use the notification service)
        print("🔔 Notification: Invoice \(invoiceId) is ready for download")
    }

    func sendOrderStatusNotification(orderId: String, status: String) async {
        // Send order status update notification
        await MainActor.run {
            NotificationCenter.default.post(
                name: .orderStatusUpdated,
                object: ["orderId": orderId, "status": status]
            )
        }
        print("🔔 Order Status Notification: Order \(orderId) status updated to \(status)")
    }

    func generateCollectionBillDocument(for trade: Trade) async {
        // Create Collection Bill document for completed trades
        let documentId = transactionIdService.generateInvoiceNumber()
        print("📄 Collection Bill Generated: \(documentId) for Trade #\(trade.tradeNumber)")

        // Create document for the Collection Bill with industry-standard naming
        let documentName = DocumentNamingUtility.traderCollectionBillName(for: trade)
        // CRITICAL: Use trade.traderId to ensure the collection bill belongs to the trade's owner
        // This ensures documents are properly isolated between traders
        let recipientId = trade.traderId
        let document = Document(
            userId: recipientId,
            name: documentName,
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "collectionbill://\(documentId).pdf",
            size: 1024 * 75, // Mock 75KB PDF size
            uploadedAt: Date(),
            tradeId: trade.id,
            documentNumber: documentId
        )

        // Add document to document service
        do {
            try await documentService.uploadDocument(document)
            print("📄 Collection Bill document added to notifications")
        } catch {
            print("❌ Failed to add Collection Bill document: \(error)")
        }

        // Send notification
        print("🔔 Notification: Trader Collection Bill \(documentId) is ready for download")
    }

    func regenerateCollectionBills(for trades: [Trade]) async {
        // CRITICAL: Only process trades belonging to the current user
        // This ensures traders only regenerate their own collection bills
        guard let currentUserId = userService.currentUser?.id else {
            print("📄 TradingNotificationService: No current user - skipping collection bill regeneration")
            return
        }

        let userTrades = trades.filter { $0.traderId == currentUserId }
        print("📄 TradingNotificationService: Checking for missing collection bills for \(userTrades.count) trades (filtered from \(trades.count) total for current trader)")

        for trade in userTrades where trade.isCompleted {
            let existingCollectionBill = documentService.documents.first {
                $0.tradeId == trade.id && $0.type == .traderCollectionBill
            }

            let shouldRegenerate: Bool
            if let existing = existingCollectionBill {
                // Check if existing Collection Bill has correct userId (should match trade.traderId)
                if existing.userId != trade.traderId {
                    print("   Found collection bill for trade #\(trade.tradeNumber) with incorrect userId (\(existing.userId) vs \(trade.traderId)) - regenerating")
                    shouldRegenerate = true
                    // Delete the old one with wrong userId
                    do {
                        try await documentService.deleteDocument(existing)
                    } catch {
                        print("   ⚠️ Failed to delete old collection bill: \(error)")
                    }
                } else {
                    shouldRegenerate = false
                }
            } else {
                print("   Found missing collection bill for trade #\(trade.tradeNumber) - regenerating")
                shouldRegenerate = true
            }

            if shouldRegenerate {
                await generateCollectionBillDocument(for: trade)
            }
        }
    }

    func sendTradeCompletionNotification(tradeId: String) async {
        // Send trade completion notification
        await MainActor.run {
            NotificationCenter.default.post(
                name: .tradeCompleted,
                object: ["tradeId": tradeId]
            )
        }
        print("🔔 Trade Completion Notification: Trade \(tradeId) completed")
    }

    func sendCommissionSettlementNotification(for trade: Trade, commissionAmount: Double, grossProfit: Double, netProfit: Double) async {
        // Create commission settlement record data
        let commissionRecord = CommissionRecord(
            tradeId: trade.id,
            traderId: trade.traderId,
            grossProfit: grossProfit,
            commissionRate: CalculationConstants.FeeRates.traderCommissionRate,
            commissionAmount: commissionAmount,
            netProfit: netProfit
        )

        // Post notification with commission settlement details
        await MainActor.run {
            NotificationCenter.default.post(
                name: .commissionSettled,
                object: commissionRecord,
                userInfo: [
                    "tradeId": trade.id,
                    "tradeNumber": trade.tradeNumber,
                    "commissionAmount": commissionAmount,
                    "grossProfit": grossProfit,
                    "netProfit": netProfit
                ]
            )
        }

        print("💰 Commission Settlement Notification: Trade #\(trade.tradeNumber)")
        print("   📊 Gross Profit: €\(String(format: "%.2f", grossProfit))")
        print("   💰 Commission: €\(String(format: "%.2f", commissionAmount))")
        print("   💵 Net Profit Distributed: €\(String(format: "%.2f", netProfit))")
        print("   ✅ Commission settled and paid to trader")
    }

    // MARK: - Credit Note Document Generation

    /// Generates a Credit Note document for the trader's commission payment
    /// - Parameters:
    ///   - trade: The completed trade
    ///   - commissionAmount: Total commission amount for the trader
    ///   - grossProfit: Total gross profit from the trade
    func generateCreditNoteDocument(for trade: Trade, commissionAmount: Double, grossProfit: Double) async {
        guard commissionAmount > 0 else {
            print("📄 CreditNote: No commission to document (amount: €\(commissionAmount))")
            return
        }

        let documentId = transactionIdService.generateInvoiceNumber()
        print("📄 Credit Note Generated: \(documentId) for Trade #\(trade.tradeNumber)")

        // CRITICAL: Use trade.traderId as customer number for proper trader isolation
        // This ensures the credit note is tied to the specific trader who owns the trade
        let customerInfo = CustomerInfo(
            name: userService.currentUser?.displayName ?? "Dr. Hans-Peter Müller",
            address: "Hauptstraße 42",
            city: "Frankfurt am Main",
            postalCode: "60311",
            taxNumber: "43/123/45678",
            depotNumber: "DE12345678901234567890",
            bank: "Deutsche Bank AG",
            customerNumber: trade.traderId  // Use trader ID for proper isolation
        )

        // Create credit note invoice
        let creditNoteInvoice = Invoice.creditNote(
            totalCommissionAmount: commissionAmount,
            customerInfo: customerInfo,
            transactionIdService: transactionIdService,
            tradeNumbers: [trade.tradeNumber],
            commissions: []  // Individual commission details are loaded dynamically in the view
        )

        // Create document name with German format
        let documentName = "Gutschrift Trade #\(String(format: "%03d", trade.tradeNumber))"
        // CRITICAL: Use trade.traderId for proper trader isolation
        let recipientId = trade.traderId

        let document = Document(
            userId: recipientId,
            name: documentName,
            type: .traderCreditNote,
            status: .verified,
            fileURL: "creditnote://\(documentId).pdf",
            size: 1024 * 45, // Mock 45KB PDF size
            uploadedAt: Date(),
            invoiceData: creditNoteInvoice,
            tradeId: trade.id,
            documentNumber: creditNoteInvoice.invoiceNumber
        )

        // Add document to document service
        do {
            try await documentService.uploadDocument(document)
            print("📄 Credit Note document added to notifications")
            print("   💰 Commission Amount: €\(String(format: "%.2f", commissionAmount))")
            print("   📊 Gross Profit: €\(String(format: "%.2f", grossProfit))")
        } catch {
            print("❌ Failed to add Credit Note document: \(error)")
        }

        // Add invoice to invoice service so it shows up in statements
        await invoiceService.addInvoice(creditNoteInvoice)
        print("📄 Credit Note added to invoice service: \(creditNoteInvoice.invoiceNumber)")

        // Send notification
        print("🔔 Notification: Credit Note \(documentId) is ready for download")
    }
}
