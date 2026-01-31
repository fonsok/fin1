import Foundation

// MARK: - Address Change Request Status

/// Status for address change requests requiring re-KYC verification
/// Follows AML/KYC compliance requirements for ongoing due diligence
enum AddressChangeRequestStatus: String, CaseIterable, Codable, Hashable {
    case pending        // Submitted, awaiting compliance review
    case underReview    // Being reviewed by compliance team
    case approved       // Approved and applied to user profile
    case rejected       // Rejected due to verification failure
    case cancelled      // Cancelled by user before review

    var displayName: String {
        switch self {
        case .pending: return "Pending Review"
        case .underReview: return "Under Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .cancelled: return "Cancelled"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .approved, .rejected, .cancelled:
            return true
        case .pending, .underReview:
            return false
        }
    }
}





