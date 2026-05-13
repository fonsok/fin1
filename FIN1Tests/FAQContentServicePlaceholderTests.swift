@testable import FIN1
import XCTest

final class FAQContentServicePlaceholderTests: XCTestCase {

    private final class StubParseAPIClient: ParseAPIClientProtocol, @unchecked Sendable {
        var functionPayloads: [String: Any] = [:]

        func fetchObjects<T: Decodable & Sendable>(
            className: String,
            query: [String: Any]?,
            include: [String]?,
            orderBy: String?,
            limit: Int?
        ) async throws -> [T] {
            []
        }

        func fetchObject<T: Decodable & Sendable>(
            className: String,
            objectId: String,
            include: [String]?
        ) async throws -> T {
            throw NetworkError.invalidResponse
        }

        func createObject<T: Encodable>(className: String, object: T) async throws -> ParseResponse {
            throw NetworkError.invalidResponse
        }

        func updateObject<T: Codable & Sendable>(
            className: String,
            objectId: String,
            object: T
        ) async throws -> ParseResponse {
            throw NetworkError.invalidResponse
        }

        func deleteObject(className: String, objectId: String) async throws {
            throw NetworkError.invalidResponse
        }

        func callFunction<T: Decodable>(_ name: String, parameters: [String: Any]?) async throws -> T {
            guard let payload = functionPayloads[name] else {
                throw NetworkError.invalidResponse
            }
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            return try JSONDecoder().decode(T.self, from: data)
        }

        func login(username: String, password: String) async throws -> ParseLoginResponse {
            throw NetworkError.invalidResponse
        }

        func resetCircuitBreaker() async {}
    }

    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        self.suiteName = "FAQContentServicePlaceholderTests-\(UUID().uuidString)"
        self.userDefaults = UserDefaults(suiteName: self.suiteName)
    }

    override func tearDown() {
        if let suiteName {
            self.userDefaults.removePersistentDomain(forName: suiteName)
        }
        self.userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFetchFAQsForLanding_ReplacesFinancialPlaceholdersInBothSyntaxes() async throws {
        let apiClient = StubParseAPIClient()
        apiClient.functionPayloads["getFAQCategories"] = [
            "categories": [[
                "objectId": "cat-1",
                "slug": "investments",
                "title": "Investments",
                "icon": "chart.pie.fill",
                "sortOrder": 1,
                "isActive": true,
                "showOnLanding": true
            ]]
        ]
        apiClient.functionPayloads["getFAQs"] = [
            "faqs": [[
                "objectId": "faq-1",
                "faqId": "faq-investor-fees",
                "question": "Welche Gebühren fallen an?",
                "answer": "Service {{APP_SERVICE_CHARGE_RATE}}, Provision {(TRADER_COMMISSION_RATE)}",
                "categoryId": "cat-1",
                "sortOrder": 1,
                "isPublished": true,
                "isArchived": false,
                "isPublic": true
            ]]
        ]

        let sut = FAQContentService(
            parseAPIClient: apiClient,
            configurationService: nil,
            userDefaults: userDefaults,
            cacheTTL: 0
        )

        let faqs = try await sut.fetchFAQsForLanding()

        XCTAssertEqual(faqs.count, 1)
        let answer = faqs[0].answer
        XCTAssertEqual(
            answer,
            "Service \(self.formatPercentDE(CalculationConstants.ServiceCharges.appServiceChargeRate)), Provision \(self.formatPercentDE(CalculationConstants.FeeRates.traderCommissionRate))"
        )
        XCTAssertFalse(answer.contains("{{APP_SERVICE_CHARGE_RATE}}"))
        XCTAssertFalse(answer.contains("{(TRADER_COMMISSION_RATE)}"))
    }

    private func formatPercentDE(_ value: Double) -> String {
        let percentValue = value * 100
        let formatted = percentValue.formatted(
            .number
                .locale(Locale(identifier: "de_DE"))
                .precision(.fractionLength(0...2))
        )
        return "\(formatted) %"
    }
}
