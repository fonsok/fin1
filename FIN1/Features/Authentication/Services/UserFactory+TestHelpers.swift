import Foundation

#if DEBUG
extension UserFactory {
    // MARK: - Test User Data Helpers

    static func extractUserNumber(from email: String) -> Int {
        let pattern = #"(\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: email.utf16.count)

        if let match = regex?.firstMatch(in: email, options: [], range: range),
           let numberRange = Range(match.range(at: 1), in: email) {
            return Int(String(email[numberRange])) ?? 1
        }
        return 1
    }

    static func getInvestorFirstName(for number: Int) -> String {
        TestConstants.investorNames[(number - 1) % TestConstants.investorNames.count].first
    }

    static func getInvestorLastName(for number: Int) -> String {
        TestConstants.investorNames[(number - 1) % TestConstants.investorNames.count].last
    }

    static func getTraderFirstName(for number: Int) -> String {
        TestConstants.traderNames[(number - 1) % TestConstants.traderNames.count].first
    }

    static func getTraderLastName(for number: Int) -> String {
        TestConstants.traderNames[(number - 1) % TestConstants.traderNames.count].last
    }

    // MARK: - CSR Role Helpers

    struct CSRInfo {
        let firstName: String
        let lastName: String
        let username: String
        let salutation: Salutation
        let roleCode: String
        let csrRole: CSRRole
    }

    static func getCSRInfo(from email: String) -> CSRInfo {
        let lowercaseEmail = email.lowercased()

        if lowercaseEmail.contains("l1") || lowercaseEmail.contains("level1") || lowercaseEmail.contains("csr1") {
            return CSRInfo(firstName: "Lisa", lastName: "Level-1", username: "csr_l1", salutation: .ms, roleCode: "L1", csrRole: .level1)
        }
        if lowercaseEmail.contains("l2") || lowercaseEmail.contains("level2") || lowercaseEmail.contains("csr2") {
            return CSRInfo(firstName: "Lars", lastName: "Level-2", username: "csr_l2", salutation: .mr, roleCode: "L2", csrRole: .level2)
        }
        if lowercaseEmail.contains("fraud") {
            return CSRInfo(firstName: "Frank", lastName: "Fraud-Analyst", username: "csr_fraud", salutation: .mr, roleCode: "FRAUD", csrRole: .fraud)
        }
        if lowercaseEmail.contains("compliance") {
            return CSRInfo(firstName: "Claudia", lastName: "Compliance", username: "csr_compliance", salutation: .ms, roleCode: "COMPL", csrRole: .compliance)
        }
        if lowercaseEmail.contains("tech") {
            return CSRInfo(firstName: "Tim", lastName: "Tech-Support", username: "csr_tech", salutation: .mr, roleCode: "TECH", csrRole: .techSupport)
        }
        if lowercaseEmail.contains("teamlead") || lowercaseEmail.contains("lead") {
            return CSRInfo(firstName: "Tanja", lastName: "Teamlead", username: "csr_teamlead", salutation: .ms, roleCode: "TL", csrRole: .teamlead)
        }
        return CSRInfo(firstName: "Customer", lastName: "Service", username: "csr", salutation: .mr, roleCode: "000", csrRole: .level1)
    }
}
#endif
