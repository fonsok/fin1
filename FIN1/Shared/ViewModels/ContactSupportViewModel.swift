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
        !self.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            self.message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    var availableCategories: [SupportCategory] {
        if self.userService.isTrader {
            return SupportCategory.allCases
        } else {
            return SupportCategory.allCases.filter { $0 != .tradingQuestion }
        }
    }

    var estimatedResponseTime: String {
        switch self.selectedCategory {
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
        let subjectEncoded = self.subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(self.supportEmail)?subject=\(subjectEncoded)")
    }

    func phoneURL() -> URL? {
        let cleanPhone = self.supportPhone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "-", with: "")
        return URL(string: "tel:\(cleanPhone)")
    }

    // MARK: - Actions

    func initiatePhoneCall() {
        self.showCallConfirmation = true
    }

    func startLiveChat() {
        // Live chat not implemented yet
        self.showLiveChatUnavailable = true
    }

    func submitRequest() {
        Task {
            await self.submitSupportRequest()
        }
    }

    func submitSupportRequest() async {
        guard self.isFormValid else { return }
        guard let userId = userService.currentUser?.id else {
            self.errorMessage = "Benutzer nicht angemeldet"
            self.showSubmitError = true
            return
        }

        self.isSubmitting = true
        defer { isSubmitting = false }

        do {
            let ticket = try await customerSupportService.createUserTicket(
                userId: userId,
                subject: self.subject.trimmingCharacters(in: .whitespacesAndNewlines),
                description: self.message.trimmingCharacters(in: .whitespacesAndNewlines),
                category: self.selectedCategory.rawValue
            )
            self.createdTicketNumber = ticket.ticketNumber
            self.showSubmitSuccess = true
        } catch {
            self.errorMessage = error.localizedDescription
            self.showSubmitError = true
        }
    }

    func resetForm() {
        self.subject = ""
        self.message = ""
        self.selectedCategory = .general
        self.attachScreenshot = false
        self.createdTicketNumber = nil
    }
}
