import Combine
import Foundation

/// ViewModel for Edit Profile view following MVVM architecture
/// Manages user profile editing state, validation, and updates.
/// Address and name changes require KYC re-verification per GwG/AML compliance.
@MainActor
final class EditProfileViewModel: ObservableObject {

    // MARK: - Dependencies

    private var userService: (any UserServiceProtocol)?
    private var addressChangeService: (any AddressChangeRequestServiceProtocol)?
    private var nameChangeService: (any NameChangeRequestServiceProtocol)?

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    @Published var showAddressChangeRequest = false
    @Published var showNameChangeRequest = false

    // MARK: - Form Fields

    @Published var salutation: Salutation = .mr
    @Published var academicTitle: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var phoneNumber: String = ""
    @Published var streetAndNumber: String = ""
    @Published var postalCode: String = ""
    @Published var city: String = ""
    @Published var state: String = ""
    @Published var country: String = ""
    @Published var employmentStatus: EmploymentStatus = .employed
    @Published var income: String = ""

    // MARK: - Computed Properties

    private var currentUser: User? { self.userService?.currentUser }
    var isIdentificationConfirmed: Bool { self.currentUser?.identificationConfirmed ?? false }
    var isAddressConfirmed: Bool { self.currentUser?.addressConfirmed ?? false }
    var isKYCCompleted: Bool { self.currentUser?.isKYCCompleted ?? false }

    var canEditName: Bool { !self.isIdentificationConfirmed }
    var nameRequiresReKYC: Bool { self.isIdentificationConfirmed }
    var canEditAddress: Bool { !self.isAddressConfirmed }
    var addressRequiresReKYC: Bool { self.isAddressConfirmed }
    var canEditEmployment: Bool { self.isKYCCompleted }

    var nameLockMessage: String {
        self.isIdentificationConfirmed
            ? "Name changes require re-verification per GwG. Tap 'Request Name Change' to submit."
            : "Complete identification verification in Get Started to edit personal information."
    }

    var addressLockMessage: String {
        self.isAddressConfirmed
            ? "Address changes require re-verification. Tap 'Request Address Change' to submit."
            : "Complete address verification in Get Started to edit address information."
    }

    var employmentLockMessage: String { "Complete KYC verification in Get Started to edit employment." }

    var pendingNameChangeRequest: NameChangeRequest? {
        guard let userId = currentUser?.id, let service = nameChangeService else { return nil }
        return service.getPendingRequest(for: userId)
    }

    var hasPendingNameChangeRequest: Bool { self.pendingNameChangeRequest != nil }

    var pendingAddressChangeRequest: AddressChangeRequest? {
        guard let userId = currentUser?.id, let service = addressChangeService else { return nil }
        return service.getPendingRequest(for: userId)
    }

    var hasPendingAddressChangeRequest: Bool { self.pendingAddressChangeRequest != nil }

    var isFormValid: Bool {
        !self.firstName.isEmpty && !self.lastName.isEmpty && !self.email.isEmpty && self.email.contains("@") &&
            !self.phoneNumber.isEmpty && !self.streetAndNumber.isEmpty && !self.postalCode.isEmpty &&
            !self.city.isEmpty && !self.country.isEmpty
    }

    var emailValidationMessage: String? {
        if self.email.isEmpty { return "Email is required" }
        if !self.email.contains("@") { return "Please enter a valid email address" }
        return nil
    }

    // MARK: - Initialization

    init() {}

    init(
        userService: any UserServiceProtocol,
        addressChangeService: any AddressChangeRequestServiceProtocol,
        nameChangeService: any NameChangeRequestServiceProtocol
    ) {
        self.userService = userService
        self.addressChangeService = addressChangeService
        self.nameChangeService = nameChangeService
        self.loadUserData()
    }

    func configure(with services: AppServices) {
        guard self.userService == nil else { return }
        self.userService = services.userService
        self.addressChangeService = services.addressChangeService
        self.nameChangeService = services.nameChangeService
        self.loadUserData()
    }

    // MARK: - Data Loading

    private func loadUserData() {
        guard let user = userService?.currentUser else { return }

        self.salutation = user.salutation
        self.academicTitle = user.academicTitle
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.email = user.email
        self.phoneNumber = user.phoneNumber
        self.streetAndNumber = user.streetAndNumber
        self.postalCode = user.postalCode
        self.city = user.city
        self.state = user.state
        self.country = user.country
        self.employmentStatus = user.employmentStatus
        self.income = user.income > 0 ? String(format: "%.0f", user.income) : ""
    }

    // MARK: - Save Profile

    @MainActor
    func saveProfile() async {
        guard let userSvc = userService, let currentUser = userSvc.currentUser else {
            self.errorMessage = "No user data available"
            return
        }

        // Validate no restricted changes
        if !self.canEditName && self.hasNameChanged(from: currentUser) {
            self.errorMessage = self.nameLockMessage
            return
        }

        if !self.canEditAddress && self.hasAddressChanged(from: currentUser) {
            self.errorMessage = self.addressLockMessage
            return
        }

        if !self.canEditEmployment && self.hasEmploymentChanged(from: currentUser) {
            self.errorMessage = self.employmentLockMessage
            return
        }

        guard self.isFormValid else {
            self.errorMessage = "Please fill in all required fields"
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        do {
            var updatedUser = currentUser
            updatedUser.salutation = self.salutation
            updatedUser.academicTitle = self.academicTitle
            updatedUser.firstName = self.firstName
            updatedUser.lastName = self.lastName
            updatedUser.email = self.email
            updatedUser.phoneNumber = self.phoneNumber
            updatedUser.streetAndNumber = self.streetAndNumber
            updatedUser.postalCode = self.postalCode
            updatedUser.city = self.city
            updatedUser.state = self.state
            updatedUser.country = self.country
            updatedUser.employmentStatus = self.employmentStatus
            updatedUser.income = Double(self.income) ?? 0.0
            updatedUser.updatedAt = Date()

            try await userSvc.updateProfile(updatedUser)

            self.isLoading = false
            self.showSuccessAlert = true
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func hasNameChanged(from user: User) -> Bool {
        self.salutation != user.salutation || self.academicTitle != user.academicTitle ||
            self.firstName != user.firstName || self.lastName != user.lastName
    }

    private func hasAddressChanged(from user: User) -> Bool {
        self.streetAndNumber != user.streetAndNumber || self.postalCode != user.postalCode ||
            self.city != user.city || self.state != user.state || self.country != user.country
    }

    private func hasEmploymentChanged(from user: User) -> Bool {
        let currentIncome = user.income > 0 ? String(format: "%.0f", user.income) : ""
        return self.employmentStatus != user.employmentStatus || self.income != currentIncome
    }
}
