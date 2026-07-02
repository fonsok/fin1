import Foundation
import SwiftUI

extension CompletedInvestmentDetailViewModel {
    struct InvestmentDetail: Identifiable {
        let id: String
        let sequenceNumber: Int
        let statusText: String
        let statusColor: Color
        let amountText: String
        let isLocked: Bool
    }

    struct TradeLineItem: Identifiable {
        let id: String
        let tradeNumber: Int
        let tradeNumberYear: Int?
        let symbol: String
        let tradeDate: Date
        let quantity: Double
        let unitPrice: Double
        let totalAmount: Double

        var formattedTradeNumber: String {
            TradeNumberFormatting.display(
                number: self.tradeNumber,
                year: self.tradeNumberYear ?? TradeNumberFormatting.calendarYear(for: self.tradeDate)
            )
        }

        var formattedQuantity: String {
            NumberFormatter.localizedDecimalFormatter.string(for: self.quantity) ?? "0,00"
        }

        var formattedUnitPrice: String {
            self.unitPrice.formattedAsLocalizedCurrency()
        }

        var formattedTotalAmount: String {
            self.totalAmount.formattedAsLocalizedCurrency()
        }
    }
}
