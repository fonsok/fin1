import Foundation
import SwiftUI

// MARK: - Investment Detail View Model
/// ViewModel for InvestmentDetailView following MVVM architecture
@MainActor
final class InvestmentDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let investment: Investment

    // MARK: - Initialization
    init(investment: Investment) {
        self.investment = investment
    }

    // MARK: - Display Properties (Formatted for UI)

    var formattedAmount: String {
        self.investment.amount.formattedAsLocalizedCurrency()
    }

    var traderIdText: String {
        self.investment.traderId
    }

    var numberOfInvestmentsText: String {
        // Show sequence number if available
        if let sequenceNumber = investment.sequenceNumber {
            return "\(sequenceNumber)"
        }
        return "1"
    }

    var specializationText: String {
        self.investment.specialization
    }

    var statusText: String {
        self.investment.status.displayName
    }

    var formattedCreatedDate: String {
        self.investment.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    var formattedUpdatedDate: String {
        self.investment.updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var hasInvestmentReservations: Bool {
        // We always have at least one investment reservation (this investment)
        true
    }

    var investmentReservations: [InvestmentReservation] {
        // Create an InvestmentReservation from the investment for backward compatibility
        [InvestmentReservation(
            id: self.investment.id,
            sequenceNumber: self.investment.sequenceNumber ?? 1,
            status: self.investment.reservationStatus,
            actualInvestmentId: nil,
            allocatedAmount: self.investment.amount,
            reservedAt: self.investment.createdAt,
            isLocked: self.investment.reservationStatus != .reserved
        )]
    }

    /// Formats reservation amount for display
    func formattedReservationAmount(_ amount: Double) -> String {
        amount.formattedAsLocalizedCurrency()
    }

    // MARK: - Error Handling

    func clearError() {
        self.errorMessage = nil
    }

    func showError(_ error: AppError) {
        self.errorMessage = error.errorDescription ?? "An error occurred"
    }
}
