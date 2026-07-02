import Foundation

extension TradingNotificationService {
    func generateCollectionBillDocument(for trade: Trade) async {
        let documentId = self.transactionIdService.generateInvoiceNumber()
        print("📄 Collection Bill Generated: \(documentId) for Trade #\(trade.tradeNumber)")

        let documentName = DocumentNamingUtility.traderCollectionBillName(for: trade)
        let recipientId = trade.traderId
        let document = Document(
            userId: recipientId,
            name: documentName,
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "collectionbill://\(documentId).pdf",
            size: 1_024 * 75,
            uploadedAt: Date(),
            tradeId: trade.id,
            documentNumber: documentId
        )

        do {
            try await self.documentService.uploadDocument(document)
            print("📄 Collection Bill document added to notifications")
        } catch {
            print("❌ Failed to add Collection Bill document: \(error)")
        }

        print("🔔 Notification: Trader Collection Bill \(documentId) is ready for download")
    }

    func regenerateCollectionBills(for trades: [Trade]) async {
        guard let currentUserId = userService.currentUser?.id else {
            print("📄 TradingNotificationService: No current user - skipping collection bill regeneration")
            return
        }

        if self.configurationService.blocksLocalInvoiceGeneration {
            print("📄 TradingNotificationService: server SSOT — skip local collection bill regeneration")
            return
        }

        let userTrades = TraderDepotTradeFilter.tradesForDepotDisplay(
            trades.filter { $0.traderId == currentUserId }
        )
        print(
            "📄 TradingNotificationService: Checking for missing collection bills for \(userTrades.count) trades (filtered from \(trades.count) total for current trader)"
        )

        for trade in userTrades where trade.isCompleted {
            let existingCollectionBill = documentService.documents.first {
                $0.tradeId == trade.id && $0.type == .traderCollectionBill
            }

            let shouldRegenerate: Bool
            if let existing = existingCollectionBill {
                if existing.userId != trade.traderId {
                    print(
                        "   Found collection bill for trade #\(trade.tradeNumber) with incorrect userId (\(existing.userId) vs \(trade.traderId)) - regenerating"
                    )
                    shouldRegenerate = true
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
}
