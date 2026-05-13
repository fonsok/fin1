import Foundation

// MARK: - Name Change Request Model

/// Represents a user's request to change their name.
/// Per GwG, name changes (especially due to marriage) require complete re-verification
/// as they imply changes to identity and risk profile.
struct NameChangeRequest: Identifiable, Codable, Hashable {
    let id: String
    let userId: String

    // Current Name (for reference)
    let currentSalutation: String
    let currentAcademicTitle: String
    let currentFirstName: String
    let currentLastName: String

    // Requested New Name
    let newSalutation: String
    let newAcademicTitle: String
    let newFirstName: String
    let newLastName: String

    // Change Details
    let reason: NameChangeReason

    // Verification Documents (at least primary document + new ID required)
    let primaryDocumentType: NameVerificationDocumentType
    let primaryDocumentURL: String?
    let identityDocumentType: NameVerificationDocumentType
    let identityDocumentURL: String?

    // Status & Timestamps
    var status: NameChangeRequestStatus
    let submittedAt: Date
    var reviewedAt: Date?
    var reviewedBy: String?
    var rejectionReason: String?

    // User Declarations
    let userDeclaration: Bool
    let acknowledgesRiskProfileUpdate: Bool

    init(
        id: String = UUID().uuidString,
        userId: String,
        currentSalutation: String,
        currentAcademicTitle: String,
        currentFirstName: String,
        currentLastName: String,
        newSalutation: String,
        newAcademicTitle: String,
        newFirstName: String,
        newLastName: String,
        reason: NameChangeReason,
        primaryDocumentType: NameVerificationDocumentType,
        primaryDocumentURL: String? = nil,
        identityDocumentType: NameVerificationDocumentType,
        identityDocumentURL: String? = nil,
        status: NameChangeRequestStatus = .pending,
        submittedAt: Date = Date(),
        reviewedAt: Date? = nil,
        reviewedBy: String? = nil,
        rejectionReason: String? = nil,
        userDeclaration: Bool,
        acknowledgesRiskProfileUpdate: Bool
    ) {
        self.id = id
        self.userId = userId
        self.currentSalutation = currentSalutation
        self.currentAcademicTitle = currentAcademicTitle
        self.currentFirstName = currentFirstName
        self.currentLastName = currentLastName
        self.newSalutation = newSalutation
        self.newAcademicTitle = newAcademicTitle
        self.newFirstName = newFirstName
        self.newLastName = newLastName
        self.reason = reason
        self.primaryDocumentType = primaryDocumentType
        self.primaryDocumentURL = primaryDocumentURL
        self.identityDocumentType = identityDocumentType
        self.identityDocumentURL = identityDocumentURL
        self.status = status
        self.submittedAt = submittedAt
        self.reviewedAt = reviewedAt
        self.reviewedBy = reviewedBy
        self.rejectionReason = rejectionReason
        self.userDeclaration = userDeclaration
        self.acknowledgesRiskProfileUpdate = acknowledgesRiskProfileUpdate
    }

    // MARK: - Computed Properties

    var currentFullName: String {
        var parts: [String] = []
        if !self.currentAcademicTitle.isEmpty { parts.append(self.currentAcademicTitle) }
        parts.append(self.currentFirstName)
        parts.append(self.currentLastName)
        return parts.joined(separator: " ")
    }

    var newFullName: String {
        var parts: [String] = []
        if !self.newAcademicTitle.isEmpty { parts.append(self.newAcademicTitle) }
        parts.append(self.newFirstName)
        parts.append(self.newLastName)
        return parts.joined(separator: " ")
    }

    var isPending: Bool { self.status == .pending || self.status == .underReview }
    var canCancel: Bool { self.status == .pending }
    var isSignificantLifeEvent: Bool { self.reason.isSignificantLifeEvent }
}

// MARK: - Name Components DTO

/// Data transfer object for name components
struct NameComponents: Codable, Hashable {
    let salutation: String
    let academicTitle: String
    let firstName: String
    let lastName: String

    var fullName: String {
        var parts: [String] = []
        if !self.academicTitle.isEmpty { parts.append(self.academicTitle) }
        parts.append(self.firstName)
        parts.append(self.lastName)
        return parts.joined(separator: " ")
    }

    var isComplete: Bool { !self.firstName.isEmpty && !self.lastName.isEmpty }
}





