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
        self.age >= 18
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
            return "\(academicTitle) \(self.fullName)"
        }
        return self.fullName
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
        if self.isTrader {
            if self.hasTradingExperience {
                return "Experienced Trader"
            } else {
                return "New Trader"
            }
        } else {
            if self.hasInvestmentExperience {
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

    /// Users with RC 1–4 cannot use dashboard investment/trading entry points.
    var isExcludedFromPlatformTradingDueToRiskClass: Bool {
        !self.riskClass.isEligibleForPlatformTrading
    }

    /// Inverse of `isExcludedFromPlatformTradingDueToRiskClass` for investment gates.
    var canCreatePlatformInvestments: Bool {
        !self.isExcludedFromPlatformTradingDueToRiskClass
    }

    /// Company accounts need KYB approval before regulated product use (mirrors `productAccessGate.js`).
    var isCompanyKybApproved: Bool {
        self.accountType != .company || self.companyKybStatus == "approved"
    }

    /// Server-aligned gate for investing/trading entry points (UI hint; server enforces via Cloud Functions).
    var isEligibleForRegulatedProductAccess: Bool {
        self.onboardingCompleted
            && self.hasAcceptedAllLegalDocuments
            && self.hasAcceptedRoleAgreementForCurrentRole
            && self.isCompanyKybApproved
            && !self.isExcludedFromPlatformTradingDueToRiskClass
    }

    /// Role agreement required for retail investor/trader (Gate 2).
    var hasAcceptedRoleAgreementForCurrentRole: Bool {
        switch self.role {
        case .trader:
            return self.acceptedTraderAgreement
        case .investor:
            return self.acceptedInvestorAgreement
        default:
            return true
        }
    }

    /// User-facing reason when `isEligibleForRegulatedProductAccess` is false (first matching rule).
    var regulatedProductAccessBlockReason: String? {
        if !self.onboardingCompleted {
            return "Bitte schließen Sie die Registrierung ab."
        }
        if !self.hasAcceptedAllLegalDocuments {
            return "Bitte akzeptieren Sie AGB und Datenschutz."
        }
        if !self.hasAcceptedRoleAgreementForCurrentRole {
            return self.role == .trader
                ? "Bitte akzeptieren Sie die Signalgeber-Vereinbarung."
                : "Bitte akzeptieren Sie die Investor-Vereinbarung."
        }
        if self.accountType == .company {
            switch self.companyKybStatus {
            case "pending_review":
                return "Ihre Firmenunterlagen werden geprüft. Investieren ist nach Freigabe möglich."
            case "more_info_requested":
                return "Bitte ergänzen Sie Ihre KYB-Angaben in der App."
            case "rejected":
                return "KYB abgelehnt — bitte kontaktieren Sie den Support."
            default:
                if !self.isCompanyKybApproved {
                    return "Bitte schließen Sie das Firmen-Onboarding (KYB) ab."
                }
            }
        }
        if self.isExcludedFromPlatformTradingDueToRiskClass {
            return nil
        }
        return nil
    }
}
