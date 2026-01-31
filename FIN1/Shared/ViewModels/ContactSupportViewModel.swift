import Foundation
import SwiftUI

// MARK: - Contact Support ViewModel
/// ViewModel for managing support contact requests from users

@MainActor
final class ContactSupportViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var subject: String = ""
    @Published var message: String = ""
    @Published var selectedCategory: SupportCategory = .general
    @Published var attachScreenshot: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var showSubmitSuccess: Bool = false
    @Published var showSubmitError: Bool = false
    @Published var errorMessage: String = ""
    @Published var createdTicketNumber: String?
    @Published var showCallConfirmation: Bool = false
    @Published var showLiveChatUnavailable: Bool = false

    // MARK: - Constants

    let supportEmail = "support@fin1app.com"
    let supportPhone = "+1 (800) 555-0199"
    let supportPhoneGermany = "+49 (0) 800 123 4567"
    let supportHours = "Mon-Fri, 9AM-6PM CET"

    // MARK: - Dependencies

    private let userService: any UserServiceProtocol
    private let customerSupportService: CustomerSupportServiceProtocol

    // MARK: - Computed Properties

    var isFormValid: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    var availableCategories: [SupportCategory] {
        if userService.isTrader {
            return SupportCategory.allCases
        } else {
            return SupportCategory.allCases.filter { $0 != .tradingQuestion }
        }
    }

    var estimatedResponseTime: String {
        switch selectedCategory {
        case .accountIssue, .security:
            return "Within 4 hours"
        case .technicalIssue:
            return "Within 24 hours"
        case .billing, .investment, .tradingQuestion:
            return "Within 1-2 business days"
        case .general, .feedback:
            return "Within 2-3 business days"
        }
    }

    // MARK: - Initialization

    init(userService: any UserServiceProtocol, customerSupportService: CustomerSupportServiceProtocol) {
        self.userService = userService
        self.customerSupportService = customerSupportService
    }

    // MARK: - URL Helpers

    func emailURL() -> URL? {
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(supportEmail)?subject=\(subjectEncoded)")
    }

    func phoneURL() -> URL? {
        let cleanPhone = supportPhone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "-", with: "")
        return URL(string: "tel:\(cleanPhone)")
    }

    // MARK: - Actions

    func initiatePhoneCall() {
        showCallConfirmation = true
    }

    func startLiveChat() {
        // Live chat not implemented yet
        showLiveChatUnavailable = true
    }

    func submitRequest() {
        Task {
            await submitSupportRequest()
        }
    }

    func submitSupportRequest() async {
        guard isFormValid else { return }
        guard let userId = userService.currentUser?.id else {
            errorMessage = "Benutzer nicht angemeldet"
            showSubmitError = true
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let ticket = try await customerSupportService.createUserTicket(
                userId: userId,
                subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                description: message.trimmingCharacters(in: .whitespacesAndNewlines),
                category: selectedCategory.rawValue
            )
            createdTicketNumber = ticket.ticketNumber
            showSubmitSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showSubmitError = true
        }
    }

    func resetForm() {
        subject = ""
        message = ""
        selectedCategory = .general
        attachScreenshot = false
        createdTicketNumber = nil
    }
}
