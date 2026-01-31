import Foundation
import Combine
import SwiftUI

// MARK: - Address Change Request ViewModel

/// ViewModel for the Address Change Request view following MVVM architecture.
/// Manages the re-KYC address verification flow for compliance.
final class AddressChangeRequestViewModel: ObservableObject {

    // MARK: - Dependencies

    private var addressChangeService: (any AddressChangeRequestServiceProtocol)?
    private var userService: (any UserServiceProtocol)?

    // MARK: - Published Properties - State

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    @Published var showCancelConfirmation = false

    // MARK: - Published Properties - Form Fields

    @Published var newStreetAndNumber: String = ""
    @Published var newPostalCode: String = ""
    @Published var newCity: String = ""
    @Published var newState: String = ""
    @Published var newCountry: String = ""

    // Document Selection
    @Published var selectedDocumentType: AddressVerificationDocumentType = .utilityBill
    @Published var selectedDocument: UIImage?

    // Declarations
    @Published var userDeclaration: Bool = false

    // MARK: - Computed Properties - Current Address

    var currentStreetAndNumber: String {
        userService?.currentUser?.streetAndNumber ?? ""
    }

    var currentPostalCode: String {
        userService?.currentUser?.postalCode ?? ""
    }

    var currentCity: String {
        userService?.currentUser?.city ?? ""
    }

    var currentState: String {
        userService?.currentUser?.state ?? ""
    }

    var currentCountry: String {
        userService?.currentUser?.country ?? ""
    }

    var currentFormattedAddress: String {
        guard let user = userService?.currentUser else { return "N/A" }
        return user.formattedAddress
    }

    // MARK: - Computed Properties - Validation

    var isFormValid: Bool {
        hasValidNewAddress &&
        hasUploadedDocument &&
        userDeclaration &&
        hasAddressChanged
    }

    var hasValidNewAddress: Bool {
        !newStreetAndNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        !newPostalCode.trimmingCharacters(in: .whitespaces).isEmpty &&
        !newCity.trimmingCharacters(in: .whitespaces).isEmpty &&
        !newCountry.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var hasUploadedDocument: Bool {
        selectedDocument != nil
    }

    var hasAddressChanged: Bool {
        newStreetAndNumber != currentStreetAndNumber ||
        newPostalCode != currentPostalCode ||
        newCity != currentCity ||
        newState != currentState ||
        newCountry != currentCountry
    }

    var newFormattedAddress: String {
        let parts = [newStreetAndNumber, newPostalCode, newCity, newState, newCountry]
            .filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    // MARK: - Pending Request

    var pendingRequest: AddressChangeRequest? {
        guard let userId = userService?.currentUser?.id,
              let service = addressChangeService else { return nil }
        return service.getPendingRequest(for: userId)
    }

    var hasPendingRequest: Bool {
        pendingRequest != nil
    }

    // MARK: - Initialization

    /// Parameterless initializer for SwiftUI views using `configure(with:)`
    init() {
        // Services will be configured via configure(with:)
    }

    /// Constructor injection for testing
    init(
        addressChangeService: any AddressChangeRequestServiceProtocol,
        userService: any UserServiceProtocol
    ) {
        self.addressChangeService = addressChangeService
        self.userService = userService
        prefillCurrentAddress()
    }

    /// Configure with app services from environment
    func configure(with services: AppServices) {
        guard addressChangeService == nil else { return }
        self.addressChangeService = services.addressChangeService
        self.userService = services.userService
        prefillCurrentAddress()
    }

    // MARK: - Private Methods

    private func prefillCurrentAddress() {
        // Pre-fill with current address as starting point
        newStreetAndNumber = currentStreetAndNumber
        newPostalCode = currentPostalCode
        newCity = currentCity
        newState = currentState
        newCountry = currentCountry
    }

    // MARK: - Public Methods

    /// Resets form to current address values
    func resetForm() {
        prefillCurrentAddress()
        selectedDocument = nil
        userDeclaration = false
        errorMessage = nil
    }

    /// Submits the address change request for compliance review
    @MainActor
    func submitRequest() async {
        guard let service = addressChangeService,
              let user = userService?.currentUser else {
            errorMessage = "User not found. Please log in again."
            return
        }

        guard isFormValid else {
            errorMessage = "Please complete all required fields and upload a verification document."
            return
        }

        isLoading = true
        errorMessage = nil

        let currentAddress = AddressComponents(
            streetAndNumber: currentStreetAndNumber,
            postalCode: currentPostalCode,
            city: currentCity,
            state: currentState,
            country: currentCountry
        )

        let newAddress = AddressComponents(
            streetAndNumber: newStreetAndNumber.trimmingCharacters(in: .whitespaces),
            postalCode: newPostalCode.trimmingCharacters(in: .whitespaces),
            city: newCity.trimmingCharacters(in: .whitespaces),
            state: newState.trimmingCharacters(in: .whitespaces),
            country: newCountry.trimmingCharacters(in: .whitespaces)
        )

        do {
            // In production, the document would be uploaded first and URL returned
            let documentURL = "document://address-verification/\(UUID().uuidString).pdf"

            _ = try await service.submitAddressChangeRequest(
                userId: user.id,
                currentAddress: currentAddress,
                newAddress: newAddress,
                documentURL: documentURL,
                documentType: selectedDocumentType,
                userDeclaration: userDeclaration
            )

            isLoading = false
            showSuccessAlert = true
        } catch {
            isLoading = false
            if let appError = error as? AppError {
                errorMessage = appError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Cancels the pending address change request
    @MainActor
    func cancelPendingRequest() async {
        guard let service = addressChangeService,
              let request = pendingRequest else {
            errorMessage = "No pending request to cancel."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await service.cancelRequest(request.id)
            isLoading = false
        } catch {
            isLoading = false
            if let appError = error as? AppError {
                errorMessage = appError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Fetches current request status
    @MainActor
    func refreshStatus() async {
        guard let service = addressChangeService,
              let userId = userService?.currentUser?.id else { return }

        isLoading = true
        do {
            try await service.fetchRequests(for: userId)
            isLoading = false
        } catch {
            isLoading = false
            // Silently fail for refresh
        }
    }
}

