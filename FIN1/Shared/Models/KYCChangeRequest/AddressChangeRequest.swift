import Foundation

// MARK: - Address Change Request Model

/// Represents a user's request to change their address.
/// KYC regulations require verification of address changes to prevent money laundering.
/// Changes are NOT applied immediately - they must be verified by compliance first.
struct AddressChangeRequest: Identifiable, Codable, Hashable {
    let id: String
    let userId: String

    // Current Address (for reference)
    let currentStreetAndNumber: String
    let currentPostalCode: String
    let currentCity: String
    let currentState: String
    let currentCountry: String

    // Requested New Address
    let newStreetAndNumber: String
    let newPostalCode: String
    let newCity: String
    let newState: String
    let newCountry: String

    // Verification Documents
    let verificationDocumentURL: String?
    let verificationDocumentType: AddressVerificationDocumentType

    // Status & Timestamps
    var status: AddressChangeRequestStatus
    let submittedAt: Date
    var reviewedAt: Date?
    var reviewedBy: String?
    var rejectionReason: String?

    // User Declaration
    let userDeclaration: Bool

    init(
        id: String = UUID().uuidString,
        userId: String,
        currentStreetAndNumber: String,
        currentPostalCode: String,
        currentCity: String,
        currentState: String,
        currentCountry: String,
        newStreetAndNumber: String,
        newPostalCode: String,
        newCity: String,
        newState: String,
        newCountry: String,
        verificationDocumentURL: String? = nil,
        verificationDocumentType: AddressVerificationDocumentType,
        status: AddressChangeRequestStatus = .pending,
        submittedAt: Date = Date(),
        reviewedAt: Date? = nil,
        reviewedBy: String? = nil,
        rejectionReason: String? = nil,
        userDeclaration: Bool
    ) {
        self.id = id
        self.userId = userId
        self.currentStreetAndNumber = currentStreetAndNumber
        self.currentPostalCode = currentPostalCode
        self.currentCity = currentCity
        self.currentState = currentState
        self.currentCountry = currentCountry
        self.newStreetAndNumber = newStreetAndNumber
        self.newPostalCode = newPostalCode
        self.newCity = newCity
        self.newState = newState
        self.newCountry = newCountry
        self.verificationDocumentURL = verificationDocumentURL
        self.verificationDocumentType = verificationDocumentType
        self.status = status
        self.submittedAt = submittedAt
        self.reviewedAt = reviewedAt
        self.reviewedBy = reviewedBy
        self.rejectionReason = rejectionReason
        self.userDeclaration = userDeclaration
    }

    // MARK: - Computed Properties

    var currentFormattedAddress: String {
        "\(self.currentStreetAndNumber), \(self.currentPostalCode) \(self.currentCity), \(self.currentState), \(self.currentCountry)"
    }

    var newFormattedAddress: String {
        "\(self.newStreetAndNumber), \(self.newPostalCode) \(self.newCity), \(self.newState), \(self.newCountry)"
    }

    var isPending: Bool { self.status == .pending || self.status == .underReview }
    var canCancel: Bool { self.status == .pending }
}

// MARK: - Address Components DTO

/// Data transfer object for address components
struct AddressComponents: Codable, Hashable {
    let streetAndNumber: String
    let postalCode: String
    let city: String
    let state: String
    let country: String

    var formattedAddress: String {
        "\(self.streetAndNumber), \(self.postalCode) \(self.city), \(self.state), \(self.country)"
    }

    var isComplete: Bool {
        !self.streetAndNumber.isEmpty && !self.postalCode.isEmpty && !self.city.isEmpty && !self.country.isEmpty
    }
}





