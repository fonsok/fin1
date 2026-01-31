import Foundation

// MARK: - User Extensions

extension User {
    /// Full name combining first and last name
    var fullName: String {
        "\(firstName) \(lastName)"
    }

    /// User's age calculated from date of birth
    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    /// Whether the user is an adult (18 or older)
    var isAdult: Bool {
        age >= 18
    }

    /// Whether the user has completed all required verification steps
    var isFullyVerified: Bool {
        isEmailVerified && isKYCCompleted && identificationConfirmed && addressConfirmed
    }

    /// Whether the user has accepted all required legal documents
    var hasAcceptedAllLegalDocuments: Bool {
        acceptedTerms && acceptedPrivacyPolicy
    }

    /// User's display name for UI purposes
    var displayName: String {
        if !academicTitle.isEmpty {
            return "\(academicTitle) \(fullName)"
        }
        return fullName
    }

    /// Formatted address string
    var formattedAddress: String {
        "\(streetAndNumber), \(postalCode) \(city), \(state), \(country)"
    }

    /// Whether the user is a trader
    var isTrader: Bool {
        role == .trader
    }

    /// Whether the user is an investor
    var isInvestor: Bool {
        role == .investor
    }

    /// Whether the user is an admin
    var isAdmin: Bool {
        role == .admin
    }

    /// Whether the user is a customer service representative
    var isCustomerService: Bool {
        role == .customerService
    }

    /// Whether the user has elevated privileges (admin or customer service)
    var hasElevatedPrivileges: Bool {
        role.hasElevatedPrivileges
    }

    /// Whether the user can view customer data (admin or customer service)
    var canViewCustomerData: Bool {
        role.canViewCustomerData
    }

    /// Whether the user is a staff member (admin or customer service)
    var isStaff: Bool {
        role == .admin || role == .customerService
    }

    /// Risk tolerance level as a descriptive string
    var riskToleranceDescription: String {
        switch riskTolerance {
        case 1...2:
            return "Conservative"
        case 3...4:
            return "Moderate"
        case 5...6:
            return "Aggressive"
        case 7...8:
            return "Very Aggressive"
        case 9...10:
            return "Extremely Aggressive"
        default:
            return "Unknown"
        }
    }

    /// Whether the user has investment experience
    var hasInvestmentExperience: Bool {
        investmentExperience > 0 || financialProductsExperience
    }

    /// Whether the user has trading experience
    var hasTradingExperience: Bool {
        tradingFrequency > 0 || leveragedProductsExperience
    }

    /// User's experience level description
    var experienceLevel: String {
        if isTrader {
            if hasTradingExperience {
                return "Experienced Trader"
            } else {
                return "New Trader"
            }
        } else {
            if hasInvestmentExperience {
                return "Experienced Investor"
            } else {
                return "New Investor"
            }
        }
    }
    
    /// User's risk class (calculated during signup Step 13+)
    /// IMPORTANT: During signup, finalRiskClass.rawValue (1-7) is stored in riskTolerance
    /// So riskTolerance actually contains the RiskClass, not the original risk tolerance (1-10)
    /// See: SignUpDataUserCreation.swift:59, UserFactory.swift:288
    var riskClass: RiskClass {
        // riskTolerance contains the RiskClass (1-7) from signup, not the original tolerance (1-10)
        return RiskClass(rawValue: riskTolerance) ?? .riskClass3 // Default to 3 if invalid
    }
}
