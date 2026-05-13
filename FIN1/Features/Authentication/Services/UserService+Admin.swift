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
}
