import Foundation

protocol FAQContentServiceProtocol {
    func fetchFAQsForHelpCenter() async throws -> [FAQContentItem]
    func fetchFAQsForLanding() async throws -> [FAQContentItem]
    func fetchFAQCategories(location: String) async throws -> [FAQCategoryContent]
}

final class FAQContentService: FAQContentServiceProtocol {
    enum Error: Swift.Error {
        case notConfigured
    }

    private let parseAPIClient: (any ParseAPIClientProtocol)?
    private let userDefaults: UserDefaults
    private let cacheTTL: TimeInterval

    init(
        parseAPIClient: (any ParseAPIClientProtocol)?,
        userDefaults: UserDefaults = .standard,
        cacheTTL: TimeInterval = 60 * 60 * 24
    ) {
        self.parseAPIClient = parseAPIClient
        self.userDefaults = userDefaults
        self.cacheTTL = cacheTTL
    }

    // MARK: - Parse DTOs

    private struct GetFAQsResult: Decodable {
        let faqs: [ParseFAQ]
    }

    private struct GetFAQCategoriesResult: Decodable {
        let categories: [ParseFAQCategory]
    }

    private struct ParseFAQCategory: Codable {
        let objectId: String
        let slug: String?
        let title: String?
        let displayName: String?
        let icon: String?
        let sortOrder: Int?
        let isActive: Bool?
        let showOnLanding: Bool?
        let showInHelpCenter: Bool?
        let showInCSR: Bool?
    }

    private struct ParseFAQ: Codable {
        let objectId: String
        let faqId: String?
        let question: String?
        let answer: String?
        let categoryId: String?
        let sortOrder: Int?
        let isPublished: Bool?
        let isArchived: Bool?
        let isPublic: Bool?
        let isUserVisible: Bool?
    }

    // MARK: - Public API

    func fetchFAQCategories(location: String) async throws -> [FAQCategoryContent] {
        let res = try await fetchRawCategories(location: location)

        let ordered = res
            .filter { ($0.isActive ?? true) }
            .sorted { a, b in
                let ao = a.sortOrder ?? Int.max
                let bo = b.sortOrder ?? Int.max
                if ao != bo { return ao < bo }
                let at = (a.title ?? a.displayName ?? a.slug ?? "")
                let bt = (b.title ?? b.displayName ?? b.slug ?? "")
                return at < bt
            }

        return ordered.compactMap { c in
            let slug = (c.slug ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let title = (c.title ?? c.displayName ?? slug).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !slug.isEmpty, !title.isEmpty else { return nil }
            return FAQCategoryContent(
                id: c.objectId,
                slug: slug,
                title: title,
                icon: (c.icon ?? "square.grid.2x2.fill"),
                sortOrder: c.sortOrder ?? Int.max
            )
        }
    }

    func fetchFAQsForHelpCenter() async throws -> [FAQContentItem] {
        try await fetchFAQsFilteredByLocation(location: "help_center")
    }

    func fetchFAQsForLanding() async throws -> [FAQContentItem] {
        try await fetchFAQsFilteredByLocation(location: "landing")
    }

    // MARK: - Internals

    private func fetchFAQsFilteredByLocation(location: String) async throws -> [FAQContentItem] {
        let categories = try await fetchRawCategories(location: location)

        // Only allow FAQs whose category is present for this location.
        var allowedCategoryIds: Set<String> = []
        var categoryIdToSortOrder: [String: Int] = [:]

        for cat in categories {
            guard (cat.isActive ?? true) else { continue }
            allowedCategoryIds.insert(cat.objectId)
            categoryIdToSortOrder[cat.objectId] = cat.sortOrder ?? Int.max
        }

        let faqsRes = try await fetchRawFAQs()

        // Keep sortOrder for stable ordering
        let itemsWithOrder: [(FAQContentItem, Int, Int)] = faqsRes.compactMap { faq in
            guard (faq.isPublished ?? true), !(faq.isArchived ?? false) else { return nil }
            guard let categoryId = faq.categoryId, allowedCategoryIds.contains(categoryId) else { return nil }

            let id = (faq.faqId?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? faq.objectId
            let question = replacePlaceholders(in: faq.question ?? "")
            let answer = replacePlaceholders(in: faq.answer ?? "")
            if question.isEmpty || answer.isEmpty { return nil }

            let item = FAQContentItem(
                id: id,
                question: question,
                answer: answer,
                categoryId: categoryId,
                sortOrder: faq.sortOrder ?? Int.max
            )
            let categoryOrder = categoryIdToSortOrder[categoryId] ?? Int.max
            let faqOrder = faq.sortOrder ?? Int.max
            return (item, categoryOrder, faqOrder)
        }

        // Stable ordering: category order then faq sortOrder then question
        return itemsWithOrder
            .sorted { a, b in
                if a.1 != b.1 { return a.1 < b.1 }
                if a.2 != b.2 { return a.2 < b.2 }
                return a.0.question < b.0.question
            }
            .map(\.0)
    }

    private func replacePlaceholders(in text: String) -> String {
        var output = text
        let replacements: [String: String] = [
            "{{APP_NAME}}": AppBrand.appName,
            "{{LEGAL_PLATFORM_NAME}}": LegalIdentity.platformName
        ]
        for (placeholder, value) in replacements {
            output = output.replacingOccurrences(of: placeholder, with: value)
        }
        return output
    }

    // MARK: - Caching (best practice: reduce network load)

    private struct CachedCategories: Codable {
        let categories: [ParseFAQCategory]
        let cachedAt: Date
    }

    private struct CachedFAQs: Codable {
        let faqs: [ParseFAQ]
        let cachedAt: Date
    }

    private func categoriesCacheKey(location: String) -> String {
        "FIN1.faq.categories.\(location)"
    }

    private func faqsCacheKey() -> String {
        "FIN1.faq.faqs.public"
    }

    private func isFresh(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) < cacheTTL
    }

    private func fetchRawCategories(location: String) async throws -> [ParseFAQCategory] {
        let key = categoriesCacheKey(location: location)
        if let data = userDefaults.data(forKey: key),
           let cached = try? JSONDecoder().decode(CachedCategories.self, from: data),
           isFresh(cached.cachedAt),
           !cached.categories.isEmpty {
            return cached.categories
        }

        guard let parseAPIClient else { throw Error.notConfigured }
        let res: GetFAQCategoriesResult = try await parseAPIClient.callFunction(
            "getFAQCategories",
            parameters: ["location": location]
        )

        let cached = CachedCategories(categories: res.categories, cachedAt: Date())
        if let data = try? JSONEncoder().encode(cached) {
            userDefaults.set(data, forKey: key)
        }
        return res.categories
    }

    private func fetchRawFAQs() async throws -> [ParseFAQ] {
        let key = faqsCacheKey()
        if let data = userDefaults.data(forKey: key),
           let cached = try? JSONDecoder().decode(CachedFAQs.self, from: data),
           isFresh(cached.cachedAt),
           !cached.faqs.isEmpty {
            return cached.faqs
        }

        guard let parseAPIClient else { throw Error.notConfigured }
        let res: GetFAQsResult = try await parseAPIClient.callFunction(
            "getFAQs",
            parameters: ["isPublic": true]
        )

        let cached = CachedFAQs(faqs: res.faqs, cachedAt: Date())
        if let data = try? JSONEncoder().encode(cached) {
            userDefaults.set(data, forKey: key)
        }
        return res.faqs
    }
}

