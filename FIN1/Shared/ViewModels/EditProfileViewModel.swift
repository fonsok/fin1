import Foundation
import Combine

/// ViewModel for Edit Profile view following MVVM architecture
/// Manages user profile editing state, validation, and updates.
/// Address and name changes require KYC re-verification per GwG/AML compliance.
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

    private var currentUser: User? { userService?.currentUser }
    var isIdentificationConfirmed: Bool { currentUser?.identificationConfirmed ?? false }
    var isAddressConfirmed: Bool { currentUser?.addressConfirmed ?? false }
    var isKYCCompleted: Bool { currentUser?.isKYCCompleted ?? false }

    var canEditName: Bool { !isIdentificationConfirmed }
    var nameRequiresReKYC: Bool { isIdentificationConfirmed }
    var canEditAddress: Bool { !isAddressConfirmed }
    var addressRequiresReKYC: Bool { isAddressConfirmed }
    var canEditEmployment: Bool { isKYCCompleted }

    var nameLockMessage: String {
        isIdentificationConfirmed
            ? "Name changes require re-verification per GwG. Tap 'Request Name Change' to submit."
            : "Complete identification verification in Get Started to edit personal information."
    }

    var addressLockMessage: String {
        isAddressConfirmed
            ? "Address changes require re-verification. Tap 'Request Address Change' to submit."
            : "Complete address verification in Get Started to edit address information."
    }

    var employmentLockMessage: String { "Complete KYC verification in Get Started to edit employment." }

    var pendingNameChangeRequest: NameChangeRequest? {
        guard let userId = currentUser?.id, let service = nameChangeService else { return nil }
        return service.getPendingRequest(for: userId)
    }

    var hasPendingNameChangeRequest: Bool { pendingNameChangeRequest != nil }

    var pendingAddressChangeRequest: AddressChangeRequest? {
        guard let userId = currentUser?.id, let service = addressChangeService else { return nil }
        return service.getPendingRequest(for: userId)
    }

    var hasPendingAddressChangeRequest: Bool { pendingAddressChangeRequest != nil }

    var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && email.contains("@") &&
        !phoneNumber.isEmpty && !streetAndNumber.isEmpty && !postalCode.isEmpty &&
        !city.isEmpty && !country.isEmpty
    }

    var emailValidationMessage: String? {
        if email.isEmpty { return "Email is required" }
        if !email.contains("@") { return "Please enter a valid email address" }
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
        loadUserData()
    }

    func configure(with services: AppServices) {
        guard userService == nil else { return }
        self.userService = services.userService
        self.addressChangeService = services.addressChangeService
        self.nameChangeService = services.nameChangeService
        loadUserData()
    }

    // MARK: - Data Loading

    private func loadUserData() {
        guard let user = userService?.currentUser else { return }

        salutation = user.salutation
        academicTitle = user.academicTitle
        firstName = user.firstName
        lastName = user.lastName
        email = user.email
        phoneNumber = user.phoneNumber
        streetAndNumber = user.streetAndNumber
        postalCode = user.postalCode
        city = user.city
        state = user.state
        country = user.country
        employmentStatus = user.employmentStatus
        income = user.income > 0 ? String(format: "%.0f", user.income) : ""
    }

    // MARK: - Save Profile

    @MainActor
    func saveProfile() async {
        guard let userSvc = userService, let currentUser = userSvc.currentUser else {
            errorMessage = "No user data available"
            return
        }

        // Validate no restricted changes
        if !canEditName && hasNameChanged(from: currentUser) {
            errorMessage = nameLockMessage
            return
        }

        if !canEditAddress && hasAddressChanged(from: currentUser) {
            errorMessage = addressLockMessage
            return
        }

        if !canEditEmployment && hasEmploymentChanged(from: currentUser) {
            errorMessage = employmentLockMessage
            return
        }

        guard isFormValid else {
            errorMessage = "Please fill in all required fields"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            var updatedUser = currentUser
            updatedUser.salutation = salutation
            updatedUser.academicTitle = academicTitle
            updatedUser.firstName = firstName
            updatedUser.lastName = lastName
            updatedUser.email = email
            updatedUser.phoneNumber = phoneNumber
            updatedUser.streetAndNumber = streetAndNumber
            updatedUser.postalCode = postalCode
            updatedUser.city = city
            updatedUser.state = state
            updatedUser.country = country
            updatedUser.employmentStatus = employmentStatus
            updatedUser.income = Double(income) ?? 0.0
            updatedUser.updatedAt = Date()

            try await userSvc.updateProfile(updatedUser)

            isLoading = false
            showSuccessAlert = true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func hasNameChanged(from user: User) -> Bool {
        salutation != user.salutation || academicTitle != user.academicTitle ||
        firstName != user.firstName || lastName != user.lastName
    }

    private func hasAddressChanged(from user: User) -> Bool {
        streetAndNumber != user.streetAndNumber || postalCode != user.postalCode ||
        city != user.city || state != user.state || country != user.country
    }

    private func hasEmploymentChanged(from user: User) -> Bool {
        let currentIncome = user.income > 0 ? String(format: "%.0f", user.income) : ""
        return employmentStatus != user.employmentStatus || income != currentIncome
    }
}
