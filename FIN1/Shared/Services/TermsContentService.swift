import Foundation

// MARK: - Terms Content Service

protocol TermsContentServiceProtocol {
    func fetchCurrentTerms(
        language: TermsOfServiceDataProvider.Language,
        documentType: LegalDocumentType
    ) async throws -> TermsContent

    func getCachedTerms(
        language: TermsOfServiceDataProvider.Language,
        documentType: LegalDocumentType
    ) -> TermsContent?

    func cacheTerms(
        _ terms: TermsContent,
        language: TermsOfServiceDataProvider.Language,
        documentType: LegalDocumentType
    )

    func clearCache()

    /// Audit trail: record that a specific document version was delivered to this device/app.
    func logDelivery(
        documentType: LegalDocumentType,
        language: TermsOfServiceDataProvider.Language,
        servedVersion: String,
        servedHash: String?,
        source: String
    ) async
}

final class TermsContentService: TermsContentServiceProtocol {
    private let parseAPIClient: (any ParseAPIClientProtocol)?
    private let userDefaults: UserDefaults

    init(parseAPIClient: (any ParseAPIClientProtocol)?, userDefaults: UserDefaults = .standard) {
        self.parseAPIClient = parseAPIClient
        self.userDefaults = userDefaults
    }

    // MARK: - Cache

    private struct CachedTermsContent: Codable {
        let content: TermsContent
        let cachedAt: Date
    }

    private func cacheKey(
        language: TermsOfServiceDataProvider.Language,
        documentType: LegalDocumentType
    ) -> String {
        "FIN1.terms_cache.\(language.rawValue).\(documentType.rawValue)"
    }

    private func deliveryDedupeKey(
        language: TermsOfServiceDataProvider.Language,
        documentType: LegalDocumentType,
        appVersion: String
    ) -> String {
        // IMPORTANT: only store "successful" deliveries here (see `logDelivery`)
        "FIN1.legal_delivery_last_success.\(language.rawValue).\(documentType.rawValue).\(appVersion)"
    }

    func getCachedTerms(
        language: TermsOfServiceDataProvider.Language,
        documentType: LegalDocumentType
    ) -> TermsContent? {
        let key = cacheKey(language: language, documentType: documentType)
        guard let data = userDefaults.data(forKey: key) else { return nil }
        guard let cached = try? JSONDecoder().decode(CachedTermsContent.self, from: data) else { return nil }
        return cached.content
    }

    func cacheTerms(
        _ terms: TermsContent,
        language: TermsOfServiceDataProvider.Language,
        documentType: LegalDocumentType
    ) {
        let key = cacheKey(language: language, documentType: documentType)
        let cached = CachedTermsContent(content: terms, cachedAt: Date())
        if let data = try? JSONEncoder().encode(cached) {
            userDefaults.set(data, forKey: key)
        }
    }

    func clearCache() {
        // Small + safe: only clear our own known prefixes
        for language in TermsOfServiceDataProvider.Language.allCases {
            for doc in LegalDocumentType.allCases {
                userDefaults.removeObject(forKey: cacheKey(language: language, documentType: doc))
            }
        }
    }

    // MARK: - Fetch

    func fetchCurrentTerms(
        language: TermsOfServiceDataProvider.Language,
        documentType: LegalDocumentType
    ) async throws -> TermsContent {
        guard let parseAPIClient else {
            throw NetworkError.invalidResponse
        }

        // Cloud function: getCurrentTerms
        let result: TermsContent = try await parseAPIClient.callFunction(
            "getCurrentTerms",
            parameters: [
                "language": language.rawValue,
                "documentType": documentType.rawValue
            ]
        )

        cacheTerms(result, language: language, documentType: documentType)
        return result
    }

    // MARK: - Audit Logging (Delivery)

    private struct DeliveryLogResult: Codable {
        let skipped: Bool?
        let objectId: String?
        let createdAt: String?
    }

    func logDelivery(
        documentType: LegalDocumentType,
        language: TermsOfServiceDataProvider.Language,
        servedVersion: String,
        servedHash: String?,
        source: String
    ) async {
        guard let parseAPIClient else { return }

        // Dedupe locally by (docType, language, appVersion, servedVersion)
        let dedupeKey = deliveryDedupeKey(
            language: language,
            documentType: documentType,
            appVersion: AppBuildInfo.appVersion
        )
        if let last = userDefaults.string(forKey: dedupeKey), last == servedVersion {
            return
        }

        var parameters: [String: Any] = [
            "documentType": documentType.rawValue,
            "language": language.rawValue,
            "servedVersion": servedVersion,
            "source": source,
            "platform": AppBuildInfo.platform,
            "appVersion": AppBuildInfo.appVersion,
            "buildNumber": AppBuildInfo.buildNumber,
            "deviceInstallId": DeviceInstallIdProvider.getOrCreate(),
            "dedupeWindowSeconds": 86400
        ]
        if let servedHash, !servedHash.isEmpty {
            parameters["servedHash"] = servedHash
        }

        let result: DeliveryLogResult? = try? await parseAPIClient.callFunction(
            "logLegalDocumentDelivery",
            parameters: parameters
        )

        // Only persist dedupe state if the server call succeeded (created or skipped).
        if result != nil {
            userDefaults.set(servedVersion, forKey: dedupeKey)
        }
    }
}

