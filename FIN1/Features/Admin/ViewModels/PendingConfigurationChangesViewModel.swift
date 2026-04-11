import Foundation
import SwiftUI
import Combine

// MARK: - Pending Configuration Changes ViewModel
/// ViewModel for managing 4-eyes approval workflow for critical configuration changes
@MainActor
final class PendingConfigurationChangesViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var pendingChanges: [PendingConfigurationChange] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Approval/Rejection state
    @Published var selectedChangeId: String?
    @Published var approvalNotes: String = ""
    @Published var rejectionReason: String = ""
    @Published var showApprovalSheet = false
    @Published var showRejectionSheet = false

    // MARK: - Private Properties
    private var configurationService: (any ConfigurationServiceProtocol)?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var hasPendingChanges: Bool {
        !pendingChanges.isEmpty
    }

    var pendingCount: Int {
        pendingChanges.count
    }

    // MARK: - Initialization
    init() {}

    // MARK: - Configuration
    func configure(with configurationService: any ConfigurationServiceProtocol) {
        self.configurationService = configurationService
    }

    // MARK: - Data Loading
    func loadPendingChanges() async {
        guard let service = configurationService as? ConfigurationService else {
            errorMessage = "Configuration service not available"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            pendingChanges = try await service.getPendingConfigurationChanges()
            print("✅ Loaded \(pendingChanges.count) pending configuration changes")
        } catch {
            errorMessage = "Failed to load pending changes: \(error.localizedDescription)"
            print("❌ Failed to load pending changes: \(error)")
        }

        isLoading = false
    }

    // MARK: - Approval Actions
    func selectForApproval(_ change: PendingConfigurationChange) {
        selectedChangeId = change.id
        approvalNotes = ""
        showApprovalSheet = true
    }

    func selectForRejection(_ change: PendingConfigurationChange) {
        selectedChangeId = change.id
        rejectionReason = ""
        showRejectionSheet = true
    }

    func approveSelectedChange() async {
        guard let changeId = selectedChangeId,
              let service = configurationService as? ConfigurationService else {
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            try await service.approveConfigurationChange(
                requestId: changeId,
                notes: approvalNotes.isEmpty ? nil : approvalNotes
            )

            successMessage = "Configuration change approved and applied"
            showApprovalSheet = false
            selectedChangeId = nil
            approvalNotes = ""

            // Reload pending changes
            await loadPendingChanges()

        } catch {
            errorMessage = "Failed to approve: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func rejectSelectedChange() async {
        guard let changeId = selectedChangeId,
              let service = configurationService as? ConfigurationService,
              !rejectionReason.isEmpty else {
            errorMessage = "Please provide a reason for rejection"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            try await service.rejectConfigurationChange(
                requestId: changeId,
                reason: rejectionReason
            )

            successMessage = "Configuration change rejected"
            showRejectionSheet = false
            selectedChangeId = nil
            rejectionReason = ""

            // Reload pending changes
            await loadPendingChanges()

        } catch {
            errorMessage = "Failed to reject: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func dismissSheets() {
        showApprovalSheet = false
        showRejectionSheet = false
        selectedChangeId = nil
        approvalNotes = ""
        rejectionReason = ""
    }

    // MARK: - Formatting Helpers
    func formatParameterName(_ name: String) -> String {
        switch name {
        case "traderCommissionRate":
            return "Trader Commission Rate"
        case "appServiceChargeRate", "platformServiceChargeRate":
            return "App Service Charge"
        case "initialAccountBalance":
            return "Initial Account Balance"
        case "orderFeeRate":
            return "Order Fee Rate"
        case "orderFeeMin":
            return "Order Fee Minimum"
        case "orderFeeMax":
            return "Order Fee Maximum"
        case "minimumCashReserve":
            return "Minimum Cash Reserve"
        default:
            return name.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
                .capitalized
        }
    }

    func formatValue(_ value: Double, for parameterName: String) -> String {
        if parameterName.lowercased().contains("rate") {
            return String(format: "%.1f%%", value * 100)
        } else {
            return NumberFormatter.currencyFormatter.string(from: NSNumber(value: value)) ?? "€\(value)"
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }

    func timeRemaining(until expiresAt: Date) -> String {
        let now = Date()
        let remaining = expiresAt.timeIntervalSince(now)

        if remaining <= 0 {
            return "Expired"
        }

        let days = Int(remaining / 86400)
        let hours = Int((remaining.truncatingRemainder(dividingBy: 86400)) / 3600)

        if days > 0 {
            return "\(days)d \(hours)h remaining"
        } else if hours > 0 {
            return "\(hours)h remaining"
        } else {
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(minutes)m remaining"
        }
    }
}

// MARK: - Number Formatter Extension
private extension NumberFormatter {
    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
}
