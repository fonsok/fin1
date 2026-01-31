import Foundation

// MARK: - User Factory
/// Handles user creation and test user generation
struct UserFactory {

    // MARK: - Regular User Creation
    private static func stableUserId(for email: String) -> String {
        // Use a deterministic ID derived from email to keep identity stable across sessions
        return "user:\(email.lowercased())"
    }

    static func createUser(from email: String, password: String) -> User {
        let isTrader = email.contains("trader")
        let userRole: UserRole = isTrader ? .trader : .investor

        return User(
            id: stableUserId(for: email),
            customerId: "\(LegalIdentity.documentPrefix)-\(Calendar.current.component(.year, from: Date()))-\(String(format: "%05d", Int.random(in: 1...99999)))",
            accountType: .individual,
            email: email,
            username: email.components(separatedBy: "@").first ?? "user",
            phoneNumber: "+1234567890",
            password: password,
            salutation: .mr,
            academicTitle: "",
            firstName: isTrader ? "Trader" : "Regular",
            lastName: "User",
            streetAndNumber: "123 Main St",
            postalCode: "10001",
            city: "New York",
            state: "NY",
            country: "United States",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date(),
            placeOfBirth: "New York",
            countryOfBirth: "United States",
            role: userRole,
            employmentStatus: .employed,
            income: 75000,
            incomeRange: .middle,
            riskTolerance: 3,
            address: "123 Main St",
            nationality: "American",
            additionalNationalities: "",
            taxNumber: "123-45-6789",
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
            leveragedProductsExperience: isTrader,
            financialProductsExperience: !isTrader,
            investmentExperience: isTrader ? 0 : 2,
            tradingFrequency: isTrader ? 1 : 0,
            investmentKnowledge: isTrader ? 0 : 2,
            desiredReturn: isTrader ? .atLeastHundredPercent : .atLeastTenPercent,
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
    }

    #if DEBUG
    // MARK: - Test User Creation

    static func createTestUser(email: String, password: String) -> User {
        let signUpData = SignUpData()

        // Determine user type and extract number from email
        if email.contains("admin") {
            // Create an admin user
            return User(
                id: stableUserId(for: email),
                customerId: signUpData.customerId,
                accountType: .company,
                email: email,
                username: "admin",
                phoneNumber: "+1234567890",
                password: password,
                salutation: .mr,
                academicTitle: "",
                firstName: "System",
                lastName: "Admin",
                streetAndNumber: "1 Admin Way",
                postalCode: "10000",
                city: "Berlin",
                state: "BE",
                country: "Germany",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date(),
                placeOfBirth: "Berlin",
                countryOfBirth: "Germany",
                role: .admin,
                employmentStatus: .employed,
                income: 0,
                incomeRange: .middle,
                riskTolerance: 1,
                address: "1 Admin Way",
                nationality: "German",
                additionalNationalities: "",
                taxNumber: "DE-ADMIN-000",
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
                leveragedProductsExperience: false,
                financialProductsExperience: true,
                investmentExperience: 0,
                tradingFrequency: 0,
                investmentKnowledge: 0,
                desiredReturn: .atLeastTenPercent,
                insiderTradingOptions: ["None of the above": true],
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
        }

        if email.contains("csr") || email.contains("customerService") || email.contains("kundenberater") {
            // Determine CSR role from email and set appropriate name
            let csrInfo = getCSRInfo(from: email)

            // Create a customer service representative user
            return User(
                id: stableUserId(for: email),
                customerId: signUpData.customerId,
                accountType: .company,
                email: email,
                username: csrInfo.username,
                phoneNumber: "+1234567890",
                password: password,
                salutation: csrInfo.salutation,
                academicTitle: "",
                firstName: csrInfo.firstName,
                lastName: csrInfo.lastName,
                streetAndNumber: "1 Support Street",
                postalCode: "10000",
                city: "Berlin",
                state: "BE",
                country: "Germany",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date(),
                placeOfBirth: "Berlin",
                countryOfBirth: "Germany",
                role: .customerService,
                csrRole: csrInfo.csrRole,
                employmentStatus: .employed,
                income: 0,
                incomeRange: .middle,
                riskTolerance: 1,
                address: "1 Support Street",
                nationality: "German",
                additionalNationalities: "",
                taxNumber: "DE-CSR-\(csrInfo.roleCode)",
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
                leveragedProductsExperience: false,
                financialProductsExperience: true,
                investmentExperience: 0,
                tradingFrequency: 0,
                investmentKnowledge: 0,
                desiredReturn: .atLeastTenPercent,
                insiderTradingOptions: ["None of the above": true],
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
        }

        let isTrader = email.contains("trader")
        let userNumber = extractUserNumber(from: email)

        // Create an investor or trader profile based on email
        if isTrader {
            signUpData.userRole = .trader
            signUpData.desiredReturn = .atLeastHundredPercent
            signUpData.derivativesTransactionsCount = .fiftyPlus
            signUpData.derivativesHoldingPeriod = .minutesToHours
            signUpData.leveragedProductsExperience = true
        } else {
            signUpData.userRole = .investor
            signUpData.financialProductsExperience = true
        }

        // Set email and name based on the user type and number
        signUpData.email = email
        signUpData.username = email.components(separatedBy: "@").first ?? "user"

        // Set names based on user type and number
        if isTrader {
            signUpData.firstName = getTraderFirstName(for: userNumber)
            signUpData.lastName = getTraderLastName(for: userNumber)
        } else {
            signUpData.firstName = getInvestorFirstName(for: userNumber)
            signUpData.lastName = getInvestorLastName(for: userNumber)
        }

        // Set other required fields
        signUpData.moneyLaunderingDeclaration = true
        signUpData.acceptedTerms = true
        signUpData.acceptedPrivacyPolicy = true
        signUpData.acceptedMarketingConsent = true

        // Create user directly from the sign up data
        return User(
            id: stableUserId(for: email),
            customerId: signUpData.customerId,
            accountType: signUpData.accountType,
            email: email,
            username: signUpData.username.isEmpty ? email.components(separatedBy: "@").first ?? "user" : signUpData.username,
            phoneNumber: signUpData.phoneNumber,
            password: password,
            salutation: signUpData.salutation,
            academicTitle: signUpData.academicTitle,
            firstName: signUpData.firstName,
            lastName: signUpData.lastName,
            streetAndNumber: signUpData.streetAndNumber,
            postalCode: signUpData.postalCode,
            city: signUpData.city,
            state: signUpData.state,
            country: signUpData.country,
            dateOfBirth: signUpData.dateOfBirth,
            placeOfBirth: signUpData.placeOfBirth,
            countryOfBirth: signUpData.countryOfBirth,
            role: signUpData.userRole,
            employmentStatus: signUpData.employmentStatus,
            income: Double(signUpData.income) ?? 0,
            incomeRange: signUpData.incomeRange,
            riskTolerance: signUpData.finalRiskClass.rawValue,
            address: signUpData.address,
            nationality: signUpData.nationality,
            additionalNationalities: signUpData.additionalNationalities,
            taxNumber: signUpData.taxNumber,
            additionalTaxResidences: signUpData.additionalResidenceCountry,
            isNotUSCitizen: signUpData.isNotUSCitizen,
            identificationType: signUpData.identificationType,
            passportFrontImageURL: nil,
            passportBackImageURL: nil,
            idCardFrontImageURL: nil,
            idCardBackImageURL: nil,
            identificationConfirmed: true,
            addressConfirmed: true,
            addressVerificationDocumentURL: nil,
            leveragedProductsExperience: signUpData.leveragedProductsExperience,
            financialProductsExperience: signUpData.financialProductsExperience,
            investmentExperience: 0,
            tradingFrequency: 0,
            investmentKnowledge: 0,
            desiredReturn: signUpData.desiredReturn,
            insiderTradingOptions: signUpData.insiderTradingOptions,
            moneyLaunderingDeclaration: signUpData.moneyLaunderingDeclaration,
            assetType: signUpData.assetType,
            profileImageURL: nil,
            isEmailVerified: true,
            isKYCCompleted: true,
            acceptedTerms: signUpData.acceptedTerms,
            acceptedPrivacyPolicy: signUpData.acceptedPrivacyPolicy,
            acceptedMarketingConsent: signUpData.acceptedMarketingConsent,
            acceptedTermsVersion: signUpData.acceptedTerms ? TermsVersionConstants.currentTermsVersion : nil,
            acceptedTermsDate: signUpData.acceptedTerms ? Date() : nil,
            acceptedPrivacyPolicyVersion: signUpData.acceptedPrivacyPolicy ? TermsVersionConstants.currentPrivacyPolicyVersion : nil,
            acceptedPrivacyPolicyDate: signUpData.acceptedPrivacyPolicy ? Date() : nil,
            lastLoginDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Test User Data Helpers

    private static func extractUserNumber(from email: String) -> Int {
        // Extract number from email like "investor1@test.com" or "trader2@test.com"
        let pattern = #"(\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: email.utf16.count)

        if let match = regex?.firstMatch(in: email, options: [], range: range),
           let numberRange = Range(match.range(at: 1), in: email) {
            return Int(String(email[numberRange])) ?? 1
        }

        return 1 // Default to 1 if no number found
    }

    private static func getInvestorFirstName(for number: Int) -> String {
        let names = ["Max", "Sarah", "Michael", "Emma", "David"]
        return names[(number - 1) % names.count]
    }

    private static func getInvestorLastName(for number: Int) -> String {
        let names = ["Investor", "Smith", "Johnson", "Williams", "Brown"]
        return names[(number - 1) % names.count]
    }

    private static func getTraderFirstName(for number: Int) -> String {
        let names = ["Thomas", "Alex", "Maria"]
        return names[(number - 1) % names.count]
    }

    private static func getTraderLastName(for number: Int) -> String {
        let names = ["Trader", "Chen", "Rodriguez"]
        return names[(number - 1) % names.count]
    }

    // MARK: - CSR Role Helpers

    /// CSR info struct for test user creation
    private struct CSRInfo {
        let firstName: String
        let lastName: String
        let username: String
        let salutation: Salutation
        let roleCode: String
        let csrRole: CSRRole
    }

    /// Extract CSR role info from email address
    /// Supports: csr-l1@, csr-l2@, csr-fraud@, csr-compliance@, csr-tech-support@, csr-teamlead@
    private static func getCSRInfo(from email: String) -> CSRInfo {
        let lowercaseEmail = email.lowercased()

        // Level 1 Support
        if lowercaseEmail.contains("l1") || lowercaseEmail.contains("level1") || lowercaseEmail.contains("csr1") {
            return CSRInfo(
                firstName: "Lisa",
                lastName: "Level-1",
                username: "csr_l1",
                salutation: .ms,
                roleCode: "L1",
                csrRole: .level1
            )
        }

        // Level 2 Support
        if lowercaseEmail.contains("l2") || lowercaseEmail.contains("level2") || lowercaseEmail.contains("csr2") {
            return CSRInfo(
                firstName: "Lars",
                lastName: "Level-2",
                username: "csr_l2",
                salutation: .mr,
                roleCode: "L2",
                csrRole: .level2
            )
        }

        // Fraud Analyst
        if lowercaseEmail.contains("fraud") {
            return CSRInfo(
                firstName: "Frank",
                lastName: "Fraud-Analyst",
                username: "csr_fraud",
                salutation: .mr,
                roleCode: "FRAUD",
                csrRole: .fraud
            )
        }

        // Compliance Officer
        if lowercaseEmail.contains("compliance") {
            return CSRInfo(
                firstName: "Claudia",
                lastName: "Compliance",
                username: "csr_compliance",
                salutation: .ms,
                roleCode: "COMPL",
                csrRole: .compliance
            )
        }

        // Tech Support
        if lowercaseEmail.contains("tech") {
            return CSRInfo(
                firstName: "Tim",
                lastName: "Tech-Support",
                username: "csr_tech",
                salutation: .mr,
                roleCode: "TECH",
                csrRole: .techSupport
            )
        }

        // Teamlead
        if lowercaseEmail.contains("teamlead") || lowercaseEmail.contains("lead") {
            return CSRInfo(
                firstName: "Tanja",
                lastName: "Teamlead",
                username: "csr_teamlead",
                salutation: .ms,
                roleCode: "TL",
                csrRole: .teamlead
            )
        }

        // Default: Generic CSR (Level 1)
        return CSRInfo(
            firstName: "Customer",
            lastName: "Service",
            username: "csr",
            salutation: .mr,
            roleCode: "000",
            csrRole: .level1
        )
    }
    #endif
}
