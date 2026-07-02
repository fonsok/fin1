import Foundation
import SwiftUI

extension CompletedInvestmentDetailViewModel {
    var investmentNumber: String { self.investment.canonicalDisplayReference }
    var traderName: String { self.investment.traderName }
    var traderSpecialization: String { self.investment.specialization }
    var statusText: String { self.investment.status.displayName }

    var statusColor: Color {
        switch self.investment.status {
        case .completed: return AppTheme.accentLightBlue
        case .cancelled: return AppTheme.accentRed
        case .active, .submitted: return AppTheme.accentGreen
        }
    }

    var completedDateText: String {
        guard let completedAt = investment.completedAt else { return "—" }
        return completedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var createdDateText: String {
        self.investment.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    var numberOfInvestmentsText: String {
        if let sequenceNumber = investment.sequenceNumber {
            return "\(sequenceNumber)"
        }
        return "1"
    }

    var activeInvestmentCountText: String {
        if self.investment.reservationStatus == .active || self.investment.reservationStatus == .executing {
            return "1"
        }
        return "0"
    }

    var completedInvestmentCountText: String {
        if self.investment.reservationStatus == .completed { return "1" }
        return "0"
    }

    var tradeNumberText: String {
        guard let firstTrade = tradeLineItems.first else { return "—" }
        return firstTrade.formattedTradeNumber
    }

    var totalInvestorQuantity: Double {
        self.tradeLineItems.reduce(0) { $0 + $1.quantity }
    }

    var totalInvestorQuantityText: String {
        NumberFormatter.localizedDecimalFormatter.string(for: self.totalInvestorQuantity) ?? "0,00"
    }

    var investmentDetails: [InvestmentDetail] {
        let statusColor: Color
        switch self.investment.reservationStatus {
        case .completed: statusColor = AppTheme.accentLightBlue
        case .active, .executing: statusColor = AppTheme.accentGreen
        case .reserved: statusColor = AppTheme.fontColor.opacity(0.8)
        case .closed: statusColor = AppTheme.accentOrange
        case .cancelled: statusColor = AppTheme.accentRed
        }

        return [InvestmentDetail(
            id: self.investment.id,
            sequenceNumber: self.investment.sequenceNumber ?? 1,
            statusText: self.investment.reservationStatus.displayName,
            statusColor: statusColor,
            amountText: self.investment.amount.formattedAsLocalizedCurrency(),
            isLocked: self.investment.reservationStatus != .reserved
        )]
    }

    var hasInvestmentDetails: Bool { !self.investmentDetails.isEmpty }
}
