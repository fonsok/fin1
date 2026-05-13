import Combine
import Foundation
import SwiftUI

// MARK: - Name Change Request ViewModel

/// ViewModel for the Name Change Request view following MVVM architecture.
/// Manages the re-KYC name verification flow for GwG compliance.
@MainActor
final class NameChangeRequestViewModel: ObservableObject {

    // MARK: - Dependencies

    private var nameChangeBridge: UncheckedNameChangeRequestServiceBridge?
    private var userService: (any UserServiceProtocol)?

    // MARK: - Published Properties - State

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    @Published var showCancelConfirmation = false

    // MARK: - Published Properties - Form Fields

    @Published var newSalutation: String = ""
    @Published var newAcademicTitle: String = ""
    @Published var newFirstName: String = ""
    @Published var newLastName: String = ""
    @Published var selectedReason: NameChangeReason = .marriage

    // Documents
    @Published var selectedPrimaryDocType: NameVerificationDocumentType = .marriageCertificate
    @Published var primaryDocument: UIImage?
    @Published var selectedIdentityDocType: NameVerificationDocumentType = .newIdCard
    @Published var identityDocument: UIImage?

    // Declarations
    @Published var userDeclaration: Bool = false
    @Published var acknowledgesRiskProfile: Bool = false

    // MARK: - Computed Properties - Current Name

    var currentSalutation: String { self.userService?.currentUser?.salutation.rawValue ?? "" }
    var currentAcademicTitle: String { self.userService?.currentUser?.academicTitle ?? "" }
    var currentFirstName: String { self.userService?.currentUser?.firstName ?? "" }
    var currentLastName: String { self.userService?.currentUser?.lastName ?? "" }

    // MARK: - Computed Properties - Validation

    var isFormValid: Bool {
        self.hasValidNewName && self.hasNameChanged && self.primaryDocument != nil &&
            self.identityDocument != nil && self.userDeclaration && self.acknowledgesRiskProfile
    }

    private var hasValidNewName: Bool {
        !self.newFirstName.trimmingCharacters(in: .whitespaces).isEmpty &&
            !self.newLastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasNameChanged: Bool {
        self.newSalutation != self.currentSalutation || self.newAcademicTitle != self.currentAcademicTitle ||
            self.newFirstName != self.currentFirstName || self.newLastName != self.currentLastName
    }

    var isSignificantLifeEvent: Bool { self.selectedReason.isSignificantLifeEvent }

    var requiredPrimaryDocumentTypes: [NameVerificationDocumentType] {
        self.selectedReason.requiredDocumentTypes.filter { $0.isPrimaryDocument }
    }

    var identityDocumentTypes: [NameVerificationDocumentType] { [.newIdCard, .newPassport] }

    var successMessage: String {
        self.isSignificantLifeEvent
            ? "Your request has been submitted. As a significant life event, it will receive priority review (1-3 business days)."
            : "Your request has been submitted for compliance review (1-3 business days)."
    }

    // MARK: - Pending Request

    var pendingRequest: NameChangeRequest? {
        guard let userId = userService?.currentUser?.id,
              let bridge = nameChangeBridge else { return nil }
        return bridge.getPendingRequest(for: userId)
    }

    var hasPendingRequest: Bool { self.pendingRequest != nil }

    // MARK: - Initialization

    init() {}

    init(nameChangeService: any NameChangeRequestServiceProtocol, userService: any UserServiceProtocol) {
        self.nameChangeBridge = UncheckedNameChangeRequestServiceBridge(nameChangeService)
        self.userService = userService
        self.prefillCurrentName()
    }

    func configure(with services: AppServices) {
        guard self.nameChangeBridge == nil else { return }
        self.nameChangeBridge = UncheckedNameChangeRequestServiceBridge(services.nameChangeService)
        self.userService = services.userService
        self.prefillCurrentName()
    }

    // MARK: - Private Methods

    private func prefillCurrentName() {
        self.newSalutation = self.currentSalutation
        self.newAcademicTitle = self.currentAcademicTitle
        self.newFirstName = self.currentFirstName
        self.newLastName = self.currentLastName
    }

    // MARK: - Public Methods

    @MainActor
    func submitRequest() async {
        guard let bridge = nameChangeBridge,
              let user = userService?.currentUser else {
            self.errorMessage = "User not found. Please log in again."
            return
        }

        guard self.isFormValid else {
            self.errorMessage = "Please complete all fields, upload documents, and accept declarations."
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        let currentName = NameComponents(
            salutation: currentSalutation,
            academicTitle: currentAcademicTitle,
            firstName: currentFirstName,
            lastName: currentLastName
        )

        let newName = NameComponents(
            salutation: newSalutation,
            academicTitle: newAcademicTitle.trimmingCharacters(in: .whitespaces),
            firstName: self.newFirstName.trimmingCharacters(in: .whitespaces),
            lastName: self.newLastName.trimmingCharacters(in: .whitespaces)
        )

        do {
            let primaryDocURL = "document://name-verification/primary/\(UUID().uuidString).pdf"
            let identityDocURL = "document://name-verification/identity/\(UUID().uuidString).pdf"

            _ = try await bridge.submitNameChangeRequest(
                userId: user.id,
                currentName: currentName,
                newName: newName,
                reason: self.selectedReason,
                primaryDocumentType: self.selectedPrimaryDocType,
                primaryDocumentURL: primaryDocURL,
                identityDocumentType: self.selectedIdentityDocType,
                identityDocumentURL: identityDocURL,
                userDeclaration: self.userDeclaration,
                acknowledgesRiskProfileUpdate: self.acknowledgesRiskProfile
            )

            self.isLoading = false
            self.showSuccessAlert = true
        } catch {
            self.isLoading = false
            self.errorMessage = (error as? AppError)?.localizedDescription ?? error.localizedDescription
        }
    }

    @MainActor
    func cancelPendingRequest() async {
        guard let bridge = nameChangeBridge, let request = pendingRequest else {
            self.errorMessage = "No pending request to cancel."
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        do {
            try await bridge.cancelRequest(request.id)
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.errorMessage = (error as? AppError)?.localizedDescription ?? error.localizedDescription
        }
    }
}
