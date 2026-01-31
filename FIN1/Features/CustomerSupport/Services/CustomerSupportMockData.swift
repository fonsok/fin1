import Foundation

// MARK: - Customer Support Mock Data
/// Mock data for development and testing purposes

enum CustomerSupportMockData {

    /// Sample customer profiles for development
    static func createMockCustomers() -> [CustomerProfile] {
        var customers: [CustomerProfile] = []

        // Test Investors (investor1@test.com through investor5@test.com)
        let investorNames = [
            (firstName: "Max", lastName: "Investor"),
            (firstName: "Sarah", lastName: "Smith"),
            (firstName: "Michael", lastName: "Johnson"),
            (firstName: "Emma", lastName: "Williams"),
            (firstName: "David", lastName: "Brown")
        ]

        for (index, name) in investorNames.enumerated() {
            let number = index + 1
            // Alternate between German and English speaking customers
            let language = index % 2 == 0 ? "German" : "English"
            customers.append(CustomerProfile(
                id: "user:investor\(number)@test.com",
                customerId: "CUST-INV-\(String(format: "%03d", number))",
                salutation: index % 2 == 0 ? "Herr" : "Frau",
                academicTitle: nil,
                firstName: name.firstName,
                lastName: name.lastName,
                email: "investor\(number)@test.com",
                phoneNumber: "+49 123 456\(String(format: "%03d", number))",
                role: "investor",
                accountType: "individual",
                createdAt: Date().addingTimeInterval(-86400.0 * Double(90 - index * 10)),
                streetAndNumber: "Investorstraße \(number)",
                postalCode: "\(10000 + number)",
                city: "Berlin",
                state: "Berlin",
                country: "Deutschland",
                language: language,
                isEmailVerified: true,
                isKYCCompleted: true,
                identificationConfirmed: true,
                addressConfirmed: true,
                accountStatus: .active,
                lastLoginDate: Date().addingTimeInterval(-Double(index) * 3600)
            ))
        }

        // Test Traders (trader1@test.com through trader3@test.com)
        let traderNames = [
            (firstName: "Thomas", lastName: "Trader"),
            (firstName: "Alex", lastName: "Chen"),
            (firstName: "Maria", lastName: "Rodriguez")
        ]

        for (index, name) in traderNames.enumerated() {
            let number = index + 1
            // Traders: German, English, Spanish
            let languages = ["German", "English", "Spanish"]
            customers.append(CustomerProfile(
                id: "user:trader\(number)@test.com",
                customerId: "CUST-TRD-\(String(format: "%03d", number))",
                salutation: index % 2 == 0 ? "Herr" : "Frau",
                academicTitle: nil,
                firstName: name.firstName,
                lastName: name.lastName,
                email: "trader\(number)@test.com",
                phoneNumber: "+49 987 654\(String(format: "%03d", number))",
                role: "trader",
                accountType: "individual",
                createdAt: Date().addingTimeInterval(-86400.0 * Double(60 - index * 10)),
                streetAndNumber: "Traderweg \(number)",
                postalCode: "\(20000 + number)",
                city: "München",
                state: "Bayern",
                country: "Deutschland",
                language: languages[index % languages.count],
                isEmailVerified: true,
                isKYCCompleted: true,
                identificationConfirmed: true,
                addressConfirmed: true,
                accountStatus: .active,
                lastLoginDate: Date().addingTimeInterval(-Double(index) * 1800)
            ))
        }

        // Original sample customers (for backward compatibility)
        customers.append(contentsOf: [
            CustomerProfile(
                id: UUID().uuidString,
                customerId: "CUST-001",
                salutation: "Herr",
                academicTitle: nil,
                firstName: "Max",
                lastName: "Mustermann",
                email: "max.mustermann@example.com",
                phoneNumber: "+49 123 456789",
                role: "investor",
                accountType: "individual",
                createdAt: Date().addingTimeInterval(-86400 * 90),
                streetAndNumber: "Musterstraße 1",
                postalCode: "12345",
                city: "Berlin",
                state: "Berlin",
                country: "Deutschland",
                language: "German",
                isEmailVerified: true,
                isKYCCompleted: true,
                identificationConfirmed: true,
                addressConfirmed: true,
                accountStatus: .active,
                lastLoginDate: Date().addingTimeInterval(-3600)
            ),
            CustomerProfile(
                id: UUID().uuidString,
                customerId: "CUST-002",
                salutation: "Frau",
                academicTitle: "Dr.",
                firstName: "Erika",
                lastName: "Musterfrau",
                email: "erika.musterfrau@example.com",
                phoneNumber: "+49 987 654321",
                role: "trader",
                accountType: "individual",
                createdAt: Date().addingTimeInterval(-86400 * 60),
                streetAndNumber: "Beispielweg 42",
                postalCode: "54321",
                city: "München",
                state: "Bayern",
                country: "Deutschland",
                language: "German",
                isEmailVerified: true,
                isKYCCompleted: false,
                identificationConfirmed: true,
                addressConfirmed: false,
                accountStatus: .pendingVerification,
                lastLoginDate: Date().addingTimeInterval(-86400)
            ),
            CustomerProfile(
                id: UUID().uuidString,
                customerId: "CUST-003",
                salutation: "Herr",
                academicTitle: "Prof. Dr.",
                firstName: "Hans",
                lastName: "Schmidt",
                email: "hans.schmidt@example.com",
                phoneNumber: "+49 555 123456",
                role: "investor",
                accountType: "individual",
                createdAt: Date().addingTimeInterval(-86400 * 180),
                streetAndNumber: "Hauptstraße 10",
                postalCode: "60311",
                city: "Frankfurt",
                state: "Hessen",
                country: "Deutschland",
                language: "English",
                isEmailVerified: true,
                isKYCCompleted: true,
                identificationConfirmed: true,
                addressConfirmed: true,
                accountStatus: .active,
                lastLoginDate: Date().addingTimeInterval(-7200)
            )
        ])

        return customers
    }

    /// Sample investments for a customer
    static func createMockInvestments(for customerId: String) -> [CustomerInvestmentSummary] {
        [
            CustomerInvestmentSummary(
                id: UUID().uuidString,
                investmentNumber: "INV-2024-001",
                traderName: "Max Trader",
                amount: 10000.0,
                currentValue: 11500.0,
                returnPercentage: 15.0,
                status: "active",
                createdAt: Date().addingTimeInterval(-86400 * 30),
                completedAt: nil
            ),
            CustomerInvestmentSummary(
                id: UUID().uuidString,
                investmentNumber: "INV-2024-002",
                traderName: "Anna Händler",
                amount: 5000.0,
                currentValue: 5250.0,
                returnPercentage: 5.0,
                status: "active",
                createdAt: Date().addingTimeInterval(-86400 * 60),
                completedAt: nil
            )
        ]
    }

    /// Sample trades for a customer
    static func createMockTrades(for customerId: String) -> [CustomerTradeSummary] {
        [
            CustomerTradeSummary(
                id: UUID().uuidString,
                tradeNumber: "TRD-2024-001",
                symbol: "AAPL",
                direction: "Buy",
                quantity: 100,
                entryPrice: 150.0,
                currentPrice: 165.0,
                profitLoss: 1500.0,
                status: "open",
                createdAt: Date().addingTimeInterval(-86400 * 7)
            )
        ]
    }

    /// Sample documents for a customer
    static func createMockDocuments(for customerId: String) -> [CustomerDocumentSummary] {
        [
            CustomerDocumentSummary(
                id: UUID().uuidString,
                name: "Personalausweis",
                type: "identity",
                uploadedAt: Date().addingTimeInterval(-86400 * 90),
                isVerified: true,
                category: "KYC"
            ),
            CustomerDocumentSummary(
                id: UUID().uuidString,
                name: "Adressnachweis",
                type: "address",
                uploadedAt: Date().addingTimeInterval(-86400 * 90),
                isVerified: true,
                category: "KYC"
            )
        ]
    }

    /// Sample support tickets for development - distributed among CSRs
    static func createMockTickets(customers: [CustomerProfile]) -> [SupportTicket] {
        guard !customers.isEmpty else { return [] }

        let customer1 = customers[0]
        let customer2 = customers.count > 1 ? customers[1] : customers[0]
        let customer3 = customers.count > 2 ? customers[2] : customers[0]

        return [
            // Unassigned ticket (in queue)
            SupportTicket(
                id: UUID().uuidString,
                ticketNumber: "TKT-12345",
                customerId: customer1.customerId,
                customerName: customer1.fullName,
                subject: "Frage zu meiner Investition",
                description: "Ich habe eine Frage bezüglich meiner Investition INV-2024-001.",
                status: .open,
                priority: .medium,
                assignedTo: nil,
                createdAt: Date().addingTimeInterval(-86400 * 2),
                updatedAt: Date().addingTimeInterval(-86400 * 2),
                responses: []
            ),
            // Assigned to CSR1 - Stefan Müller (General Support)
            SupportTicket(
                id: UUID().uuidString,
                ticketNumber: "TKT-12346",
                customerId: customer2.customerId,
                customerName: customer2.fullName,
                subject: "Problem beim Login",
                description: "Ich kann mich nicht mehr in mein Konto einloggen.",
                status: .inProgress,
                priority: .high,
                assignedTo: "user:csr1@test.com",
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date().addingTimeInterval(-3600),
                responses: [
                    TicketResponse(
                        id: UUID().uuidString,
                        agentId: "user:csr1@test.com",
                        agentName: "Stefan Müller",
                        message: "Wir haben Ihr Problem erhalten und bearbeiten es.",
                        isInternal: false,
                        createdAt: Date().addingTimeInterval(-3600)
                    )
                ]
            ),
            // Assigned to CSR2 - Anna Schmidt (Billing)
            SupportTicket(
                id: UUID().uuidString,
                ticketNumber: "TKT-12347",
                customerId: customer3.customerId,
                customerName: customer3.fullName,
                subject: "Rechnung nicht erhalten",
                description: "Ich habe meine monatliche Rechnung nicht per E-Mail erhalten.",
                status: .inProgress,
                priority: .medium,
                assignedTo: "user:csr2@test.com",
                createdAt: Date().addingTimeInterval(-86400 * 3),
                updatedAt: Date().addingTimeInterval(-7200),
                responses: []
            ),
            // Assigned to CSR3 - Markus Weber (Technical)
            SupportTicket(
                id: UUID().uuidString,
                ticketNumber: "TKT-12348",
                customerId: customer1.customerId,
                customerName: customer1.fullName,
                subject: "App stürzt beim Öffnen ab",
                description: "Die App stürzt jedes Mal ab, wenn ich sie öffne. iOS 17.2.",
                status: .inProgress,
                priority: .high,
                assignedTo: "user:csr3@test.com",
                createdAt: Date().addingTimeInterval(-86400 * 1.5),
                updatedAt: Date().addingTimeInterval(-1800),
                responses: [
                    TicketResponse(
                        id: UUID().uuidString,
                        agentId: "user:csr3@test.com",
                        agentName: "Markus Weber",
                        message: "Können Sie bitte die App-Version und Ihr Gerätemodell angeben?",
                        isInternal: false,
                        createdAt: Date().addingTimeInterval(-1800)
                    )
                ]
            )
        ]
    }

    /// Create mock CSR agents matching test users (csr1, csr2, csr3)
    /// Ticket counts should roughly match the mock tickets above
    static func createMockAgents() -> [CSRAgent] {
        [
            CSRAgent(
                id: "user:csr1@test.com",
                name: "Stefan Müller",
                email: "csr1@test.com",
                specializations: [
                    AgentSpecialization.general.rawValue,
                    AgentSpecialization.account.rawValue
                ],
                languages: ["German", "English"],
                isAvailable: true,
                currentTicketCount: 1  // Has 1 mock ticket assigned
            ),
            CSRAgent(
                id: "user:csr2@test.com",
                name: "Anna Schmidt",
                email: "csr2@test.com",
                specializations: [
                    AgentSpecialization.billing.rawValue,
                    AgentSpecialization.investments.rawValue
                ],
                languages: ["German", "English", "French"],
                isAvailable: true,
                currentTicketCount: 1  // Has 1 mock ticket assigned
            ),
            CSRAgent(
                id: "user:csr3@test.com",
                name: "Markus Weber",
                email: "csr3@test.com",
                specializations: [
                    AgentSpecialization.technical.rawValue,
                    AgentSpecialization.security.rawValue
                ],
                languages: ["German", "English"],
                isAvailable: true,
                currentTicketCount: 1  // Has 1 mock ticket assigned
            )
        ]
    }
}





