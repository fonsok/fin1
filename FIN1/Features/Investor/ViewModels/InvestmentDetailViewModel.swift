import SwiftUI
import Foundation

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
        investment.amount.formattedAsLocalizedCurrency()
    }

    var traderIdText: String {
        investment.traderId
    }

    var numberOfInvestmentsText: String {
        // Show sequence number if available
        if let sequenceNumber = investment.sequenceNumber {
            return "\(sequenceNumber)"
        }
        return "1"
    }

    var specializationText: String {
        investment.specialization
    }

    var statusText: String {
        investment.status.displayName
    }

    var formattedCreatedDate: String {
        investment.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    var formattedUpdatedDate: String {
        investment.updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var hasInvestmentReservations: Bool {
        // We always have at least one investment reservation (this investment)
        true
    }

    var investmentReservations: [InvestmentReservation] {
        // Create an InvestmentReservation from the investment for backward compatibility
        [InvestmentReservation(
            id: investment.id,
            sequenceNumber: investment.sequenceNumber ?? 1,
            status: investment.reservationStatus,
            actualInvestmentId: nil,
            allocatedAmount: investment.amount,
            reservedAt: investment.createdAt,
            isLocked: investment.reservationStatus != .reserved
        )]
    }

    /// Formats reservation amount for display
    func formattedReservationAmount(_ amount: Double) -> String {
        amount.formattedAsLocalizedCurrency()
    }

    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
    }

    func showError(_ error: AppError) {
        errorMessage = error.errorDescription ?? "An error occurred"
    }
}
