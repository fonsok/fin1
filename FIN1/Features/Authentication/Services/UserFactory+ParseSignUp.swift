import Foundation

extension UserFactory {

    /// Builds the JSON body for Parse REST `POST /users` during onboarding account creation.
    static func parseSignUpParameters(from user: User) -> [String: Any] {
        var body: [String: Any] = [
            "username": user.username,
            "password": user.password,
            "email": user.email.lowercased().trimmingCharacters(in: .whitespaces),
            "role": user.role.rawValue,
            "customerNumber": user.customerNumber,
            "accountType": user.accountType.rawValue,
            "status": "active",
            "onboardingCompleted": false,
            "onboardingStep": SignUpStep.contact.backendKey,
            "kycStatus": "pending",
            "isEmailVerified": false,
            "isPhoneVerified": false
        ]

        if !user.phoneNumber.isEmpty { body["phoneNumber"] = user.phoneNumber }
        if !user.firstName.isEmpty { body["firstName"] = user.firstName }
        if !user.lastName.isEmpty { body["lastName"] = user.lastName }
        if !user.streetAndNumber.isEmpty { body["streetAndNumber"] = user.streetAndNumber }
        if !user.postalCode.isEmpty { body["postalCode"] = user.postalCode }
        if !user.city.isEmpty { body["city"] = user.city }
        if !user.state.isEmpty { body["state"] = user.state }
        if !user.country.isEmpty { body["country"] = user.country }
        if !user.placeOfBirth.isEmpty { body["placeOfBirth"] = user.placeOfBirth }
        if !user.countryOfBirth.isEmpty { body["countryOfBirth"] = user.countryOfBirth }
        if !user.nationality.isEmpty { body["nationality"] = user.nationality }
        if !user.taxNumber.isEmpty { body["taxNumber"] = user.taxNumber }

        body["salutation"] = user.salutation.rawValue
        body["employmentStatus"] = user.employmentStatus.rawValue
        body["incomeRange"] = user.incomeRange.rawValue
        body["isNotUSCitizen"] = user.isNotUSCitizen
        if let identificationType = user.identificationType {
            body["identificationType"] = identificationType.rawValue
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        body["dateOfBirth"] = formatter.string(from: user.dateOfBirth)

        return body
    }
}
