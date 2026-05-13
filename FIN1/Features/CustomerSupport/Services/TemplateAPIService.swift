import Foundation

// MARK: - Template API Service Protocol

/// Protocol for template service operations
protocol TemplateAPIServiceProtocol: Sendable {
    /// Fetches response templates for a specific CSR role
    func fetchResponseTemplates(
        for role: CSRRole,
        category: TemplateCategory?,
        forceRefresh: Bool
    ) async throws -> [ResponseTemplate]

    /// Fetches email templates
    func fetchEmailTemplates(forceRefresh: Bool) async throws -> [EmailTemplate]

    /// Fetches template categories
    func fetchCategories(forceRefresh: Bool) async throws -> [TemplateCategoryDTO]

    /// Records template usage for analytics
    func recordUsage(templateId: String, ticketId: String?) async throws

    /// Clears all cached templates
    func clearCache()
}

// MARK: - Template Category DTO (from Backend)

struct TemplateCategoryDTO: Codable, Identifiable {
    let id: String
    let key: String
    let displayName: String
    let icon: String
    let sortOrder: Int

    var templateCategory: TemplateCategory? {
        TemplateCategory(rawValue: self.key)
    }
}

// MARK: - Backend Response Template DTO

struct BackendResponseTemplate: Codable {
    let id: String
    let templateKey: String?
    let title: String
    let category: String
    let subject: String?
    let body: String
    let isEmail: Bool
    let placeholders: [String]
    let shortcut: String?
    let usageCount: Int
    let isDefault: Bool
    let version: Int
    let updatedAt: String?

    /// Converts to local ResponseTemplate model
    func toResponseTemplate() -> ResponseTemplate {
        let category = TemplateCategory(rawValue: self.category) ?? .general

        return ResponseTemplate(
            id: self.id,
            title: self.title,
            category: category,
            subject: self.subject,
            body: self.body,
            availableForRoles: [], // Not needed locally since we already filtered by role
            placeholders: self.placeholders,
            isEmail: self.isEmail
        )
    }
}

// MARK: - Backend Email Template DTO

struct BackendEmailTemplate: Codable {
    let id: String
    let type: String
    let displayName: String
    let icon: String?
    let subject: String
    let bodyTemplate: String
    let availablePlaceholders: [String]
    let isActive: Bool
    let version: Int
    let updatedAt: String?

    /// Converts to local EmailTemplate model
    func toEmailTemplate() -> EmailTemplate? {
        guard let templateType = EmailTemplateType(rawValue: displayName) ?? emailTypeFromKey(type) else {
            return nil
        }

        return EmailTemplate(
            id: self.id,
            type: templateType,
            subject: self.subject,
            bodyTemplate: self.bodyTemplate,
            isActive: self.isActive,
            lastModified: self.parseDate(self.updatedAt) ?? Date()
        )
    }

    private func emailTypeFromKey(_ key: String) -> EmailTemplateType? {
        switch key {
        case "ticket_created": return .ticketCreated
        case "ticket_response": return .ticketResponse
        case "ticket_status_change": return .ticketStatusChange
        case "ticket_resolved": return .ticketResolved
        case "ticket_closed": return .ticketClosed
        case "survey_request": return .surveyRequest
        case "sla_warning": return .slaWarning
        default: return nil
        }
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}

// MARK: - Template API Service Implementation

/// Service for fetching and caching CSR templates from the backend
/// Provides offline support through local caching
final class TemplateAPIService: TemplateAPIServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let apiClient: ParseAPIClientProtocol
    private let cache = TemplateCache.shared
    private let preferredLanguage: String

    // MARK: - Initialization

    init(apiClient: ParseAPIClientProtocol, preferredLanguage: String = "de") {
        self.apiClient = apiClient
        self.preferredLanguage = preferredLanguage
    }

    // MARK: - Response Templates

    func fetchResponseTemplates(
        for role: CSRRole,
        category: TemplateCategory? = nil,
        forceRefresh: Bool = false
    ) async throws -> [ResponseTemplate] {
        let cacheKey = "templates_\(role.roleKey)_\(category?.rawValue ?? "all")"

        // Check cache if not forcing refresh
        if !forceRefresh, let cached = cache.getTemplates(forKey: cacheKey) {
            return cached
        }

        // Build parameters
        var params: [String: Any] = [
            "role": role.roleKey,
            "language": self.preferredLanguage
        ]

        if let category = category {
            params["category"] = category.rawValue
        }

        // Fetch from backend
        let backendTemplates: [BackendResponseTemplate] = try await apiClient.callFunction(
            "getResponseTemplates",
            parameters: params
        )

        // Convert to local models
        let templates = backendTemplates.map { $0.toResponseTemplate() }

        // Cache the results
        self.cache.setTemplates(templates, forKey: cacheKey)

        return templates
    }

    // MARK: - Email Templates

    func fetchEmailTemplates(forceRefresh: Bool = false) async throws -> [EmailTemplate] {
        let cacheKey = "email_templates"

        // Check cache if not forcing refresh
        if !forceRefresh, let cached = cache.getEmailTemplates(forKey: cacheKey) {
            return cached
        }

        let params: [String: Any] = [
            "language": preferredLanguage
        ]

        // Fetch from backend
        let backendTemplates: [BackendEmailTemplate] = try await apiClient.callFunction(
            "getEmailTemplates",
            parameters: params
        )

        // Convert to local models
        let templates = backendTemplates.compactMap { $0.toEmailTemplate() }

        // Cache the results
        self.cache.setEmailTemplates(templates, forKey: cacheKey)

        return templates
    }

    // MARK: - Categories

    func fetchCategories(forceRefresh: Bool = false) async throws -> [TemplateCategoryDTO] {
        let cacheKey = "template_categories"

        // Check cache if not forcing refresh
        if !forceRefresh, let cached = cache.getCategories(forKey: cacheKey) {
            return cached
        }

        let params: [String: Any] = [
            "language": preferredLanguage
        ]

        // Fetch from backend
        let categories: [TemplateCategoryDTO] = try await apiClient.callFunction(
            "getTemplateCategories",
            parameters: params
        )

        // Cache the results
        self.cache.setCategories(categories, forKey: cacheKey)

        return categories
    }

    // MARK: - Usage Tracking

    func recordUsage(templateId: String, ticketId: String? = nil) async throws {
        var params: [String: Any] = [
            "templateId": templateId
        ]

        if let ticketId = ticketId {
            params["ticketId"] = ticketId
        }

        // Fire and forget - don't block on analytics
        let client: any ParseAPIClientProtocol = self.apiClient
        let paramsCopy = params
        Task.detached(priority: .utility) {
            do {
                let _: EmptyResponse = try await client.callFunction(
                    "recordTemplateUsage",
                    parameters: paramsCopy
                )
            } catch {
                // Log but don't throw - analytics should not fail operations
                print("⚠️ Failed to record template usage: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cache Management

    func clearCache() {
        self.cache.clearAll()
    }
}

// MARK: - Empty Response Helper

private struct EmptyResponse: Codable {
    let success: Bool?
}

// MARK: - Template Cache

/// Thread-safe cache for CSR templates with TTL support
final class TemplateCache: @unchecked Sendable {
    static let shared = TemplateCache()

    private var templateCache: [String: CachedItem<[ResponseTemplate]>] = [:]
    private var emailTemplateCache: [String: CachedItem<[EmailTemplate]>] = [:]
    private var categoryCache: [String: CachedItem<[TemplateCategoryDTO]>] = [:]

    private let lock = NSLock()
    private let defaultTTL: TimeInterval = 300 // 5 minutes

    private init() {}

    // MARK: - Response Templates

    func getTemplates(forKey key: String) -> [ResponseTemplate]? {
        self.lock.lock()
        defer { lock.unlock() }

        guard let cached = templateCache[key], !cached.isExpired else {
            self.templateCache.removeValue(forKey: key)
            return nil
        }
        return cached.value
    }

    func setTemplates(_ templates: [ResponseTemplate], forKey key: String, ttl: TimeInterval? = nil) {
        self.lock.lock()
        defer { lock.unlock() }

        self.templateCache[key] = CachedItem(value: templates, ttl: ttl ?? self.defaultTTL)
    }

    // MARK: - Email Templates

    func getEmailTemplates(forKey key: String) -> [EmailTemplate]? {
        self.lock.lock()
        defer { lock.unlock() }

        guard let cached = emailTemplateCache[key], !cached.isExpired else {
            self.emailTemplateCache.removeValue(forKey: key)
            return nil
        }
        return cached.value
    }

    func setEmailTemplates(_ templates: [EmailTemplate], forKey key: String, ttl: TimeInterval? = nil) {
        self.lock.lock()
        defer { lock.unlock() }

        self.emailTemplateCache[key] = CachedItem(value: templates, ttl: ttl ?? self.defaultTTL)
    }

    // MARK: - Categories

    func getCategories(forKey key: String) -> [TemplateCategoryDTO]? {
        self.lock.lock()
        defer { lock.unlock() }

        guard let cached = categoryCache[key], !cached.isExpired else {
            self.categoryCache.removeValue(forKey: key)
            return nil
        }
        return cached.value
    }

    func setCategories(_ categories: [TemplateCategoryDTO], forKey key: String, ttl: TimeInterval? = nil) {
        self.lock.lock()
        defer { lock.unlock() }

        self.categoryCache[key] = CachedItem(value: categories, ttl: ttl ?? self.defaultTTL)
    }

    // MARK: - Clear

    func clearAll() {
        self.lock.lock()
        defer { lock.unlock() }

        self.templateCache.removeAll()
        self.emailTemplateCache.removeAll()
        self.categoryCache.removeAll()
    }
}

// MARK: - Cached Item

private struct CachedItem<T> {
    let value: T
    let expiresAt: Date

    init(value: T, ttl: TimeInterval) {
        self.value = value
        self.expiresAt = Date().addingTimeInterval(ttl)
    }

    var isExpired: Bool {
        Date() > self.expiresAt
    }
}

// MARK: - CSRRole Extension

extension CSRRole {
    /// Maps to backend role key
    var roleKey: String {
        switch self {
        case .level1: return "level_1"
        case .level2: return "level_2"
        case .fraud: return "fraud_analyst"
        case .compliance: return "compliance_officer"
        case .techSupport: return "tech_support"
        case .teamlead: return "teamlead"
        }
    }
}

// MARK: - Fallback to Static Templates

/// Extension to provide fallback to static templates when backend is unavailable
extension TemplateAPIService {

    /// Fetches templates with fallback to static templates if backend fails
    func fetchTemplatesWithFallback(
        for role: CSRRole,
        category: TemplateCategory? = nil
    ) async -> [ResponseTemplate] {
        do {
            return try await self.fetchResponseTemplates(for: role, category: category, forceRefresh: false)
        } catch {
            print("⚠️ Backend templates unavailable, using static fallback: \(error.localizedDescription)")
            // Fallback to static templates
            if let category = category {
                return CSRTemplatesLibrary.templates(for: role, category: category)
            } else {
                return CSRTemplatesLibrary.templates(for: role)
            }
        }
    }

    /// Fetches email templates with fallback to static templates if backend fails
    func fetchEmailTemplatesWithFallback() async -> [EmailTemplate] {
        do {
            return try await self.fetchEmailTemplates(forceRefresh: false)
        } catch {
            print("⚠️ Backend email templates unavailable, using static fallback: \(error.localizedDescription)")
            return EmailTemplate.defaults
        }
    }
}
