import Foundation

extension UserService {
    // MARK: - Role Management (Admin)

    @MainActor
    func switchUserRole(to newRole: UserRole) async {
        guard let user = currentUser else { return }

        let updatedUser = User(
            id: user.id,
            customerNumber: user.customerNumber,
            accountType: user.accountType,
            email: user.email,
            username: user.username,
            phoneNumber: user.phoneNumber,
            password: user.password,
            salutation: user.salutation,
            academicTitle: user.academicTitle,
            firstName: user.firstName,
            lastName: user.lastName,
            streetAndNumber: user.streetAndNumber,
            postalCode: user.postalCode,
            city: user.city,
            state: user.state,
            country: user.country,
            dateOfBirth: user.dateOfBirth,
            placeOfBirth: user.placeOfBirth,
            countryOfBirth: user.countryOfBirth,
            role: newRole,
            employmentStatus: user.employmentStatus,
            income: user.income,
            incomeRange: user.incomeRange,
            riskTolerance: user.riskTolerance,
            address: user.address,
            nationality: user.nationality,
            additionalNationalities: user.additionalNationalities,
            taxNumber: user.taxNumber,
            additionalTaxResidences: user.additionalTaxResidences,
            isNotUSCitizen: user.isNotUSCitizen,
            identificationType: user.identificationType,
            passportFrontImageURL: user.passportFrontImageURL,
            passportBackImageURL: user.passportBackImageURL,
            idCardFrontImageURL: user.idCardFrontImageURL,
            idCardBackImageURL: user.idCardBackImageURL,
            identificationConfirmed: user.identificationConfirmed,
            addressConfirmed: user.addressConfirmed,
            addressVerificationDocumentURL: user.addressVerificationDocumentURL,
            leveragedProductsExperience: user.leveragedProductsExperience,
            financialProductsExperience: user.financialProductsExperience,
            investmentExperience: user.investmentExperience,
            tradingFrequency: user.tradingFrequency,
            investmentKnowledge: user.investmentKnowledge,
            desiredReturn: user.desiredReturn,
            insiderTradingOptions: user.insiderTradingOptions,
            moneyLaunderingDeclaration: user.moneyLaunderingDeclaration,
            assetType: user.assetType,
            profileImageURL: user.profileImageURL,
            isEmailVerified: user.isEmailVerified,
            isKYCCompleted: user.isKYCCompleted,
            acceptedTerms: user.acceptedTerms,
            acceptedPrivacyPolicy: user.acceptedPrivacyPolicy,
            acceptedMarketingConsent: user.acceptedMarketingConsent,
            acceptedTermsVersion: user.acceptedTermsVersion,
            acceptedTermsDate: user.acceptedTermsDate,
            acceptedPrivacyPolicyVersion: user.acceptedPrivacyPolicyVersion,
            acceptedPrivacyPolicyDate: user.acceptedPrivacyPolicyDate,
            lastLoginDate: user.lastLoginDate,
            createdAt: user.createdAt,
            updatedAt: Date()
        )

        currentUser = updatedUser
        NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("UserRoleChanged"), object: newRole)
        print("🔄 UserService: Role switched to \(newRole.displayName)")
    }

    // MARK: - User Impersonation (Admin)

    @MainActor
    func impersonateUser(userId: String, customerNumber: String, email: String, fullName: String, role: UserRole) async {
        if _originalAdminUser == nil, let currentUser = currentUser, currentUser.role == .admin {
            _originalAdminUser = currentUser
            print("💾 UserService: Stored original admin user: \(currentUser.displayName)")
        }

        let nameComponents = fullName.components(separatedBy: " ")
        let firstName = nameComponents.first ?? ""
        let lastName = nameComponents.dropFirst().joined(separator: " ")

        let impersonatedUser = User(
            id: userId,
            customerNumber: customerNumber,
            accountType: .individual,
            email: email,
            username: email.components(separatedBy: "@").first ?? "",
            phoneNumber: "",
            password: "",
            salutation: .mr,
            academicTitle: "",
            firstName: firstName,
            lastName: lastName.isEmpty ? firstName : lastName,
            streetAndNumber: "",
            postalCode: "",
            city: "",
            state: "",
            country: "",
            dateOfBirth: Date(),
            placeOfBirth: "",
            countryOfBirth: "",
            role: role,
            employmentStatus: .employed,
            income: 0,
            incomeRange: .low,
            riskTolerance: 3,
            address: "",
            nationality: "",
            additionalNationalities: "",
            taxNumber: "",
            additionalTaxResidences: "",
            isNotUSCitizen: true,
            identificationType: .passport,
            passportFrontImageURL: nil,
            passportBackImageURL: nil,
            idCardFrontImageURL: nil,
            idCardBackImageURL: nil,
            identificationConfirmed: true,
            addressConfirmed: true,
            addressVerificationDocumentURL: nil,
            leveragedProductsExperience: role == .trader,
            financialProductsExperience: role == .investor,
            investmentExperience: role == .investor ? 2 : 0,
            tradingFrequency: role == .trader ? 1 : 0,
            investmentKnowledge: role == .investor ? 2 : 0,
            desiredReturn: role == .trader ? .atLeastHundredPercent : .atLeastTenPercent,
            insiderTradingOptions: [
                "Brokerage or Stock Exchange Employee": false,
                "Director or 10% Shareholder": false,
                "High-Ranking Official": false,
                "None of the above": true
            ],
            moneyLaunderingDeclaration: true,
            assetType: .privateAssets,
            profileImageURL: nil,
            isEmailVerified: true,
            isKYCCompleted: true,
            acceptedTerms: true,
            acceptedPrivacyPolicy: true,
            acceptedMarketingConsent: true,
            acceptedTermsVersion: TermsVersionConstants.currentTermsVersion,
            acceptedTermsDate: Date(),
            acceptedPrivacyPolicyVersion: TermsVersionConstants.currentPrivacyPolicyVersion,
            acceptedPrivacyPolicyDate: Date(),
            lastLoginDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )

        currentUser = impersonatedUser
        NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("UserRoleChanged"), object: role)
        NotificationCenter.default.post(name: NSNotification.Name("UserImpersonationStarted"), object: nil)
        print("👤 UserService: Impersonating user \(fullName) (\(role.displayName)) - ID: \(userId)")
    }

    @MainActor
    func stopImpersonating() async {
        guard let originalUser = _originalAdminUser else {
            print("⚠️ UserService: No original admin user to return to")
            return
        }

        currentUser = originalUser
        _originalAdminUser = nil
        NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("UserRoleChanged"), object: originalUser.role)
        NotificationCenter.default.post(name: NSNotification.Name("UserImpersonationStopped"), object: nil)
        print("🔙 UserService: Stopped impersonation, returned to admin: \(originalUser.displayName)")
    }
}
