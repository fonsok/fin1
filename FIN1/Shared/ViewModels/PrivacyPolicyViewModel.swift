import Foundation
import Combine

/// ViewModel for Privacy Policy view
/// Manages section expansion, search filtering, and jurisdiction-based content
final class PrivacyPolicyViewModel: ObservableObject {

    // MARK: - Type Aliases

    typealias Jurisdiction = PrivacyPolicyDataProvider.Jurisdiction
    typealias PrivacySection = PrivacyPolicyDataProvider.PrivacySection

    // MARK: - Dependencies

    private let userService: (any UserServiceProtocol)?
    private let termsContentService: (any TermsContentServiceProtocol)?

    // MARK: - Published Properties

    @Published var searchQuery = ""
    @Published var expandedSectionIds: Set<String> = []
    @Published var scrollToSectionId: String?
    @Published private(set) var currentJurisdiction: Jurisdiction
    @Published private(set) var serverPrivacyContent: TermsContent?
    @Published private(set) var serverContentSource: String?

    // MARK: - Initialization

    init(
        userService: (any UserServiceProtocol)? = nil,
        termsContentService: (any TermsContentServiceProtocol)? = nil
    ) {
        self.userService = userService
        self.termsContentService = termsContentService

        // Determine jurisdiction from current user
        if let currentUser = userService?.currentUser {
            currentJurisdiction = PrivacyPolicyDataProvider.determineJurisdiction(
                country: currentUser.country,
                nationality: currentUser.nationality,
                isNotUSCitizen: currentUser.isNotUSCitizen
            )
        } else {
            // Default to German if no user data available
            currentJurisdiction = .german
        }

        Task { [weak self] in
            await self?.loadServerDrivenPrivacyIfAvailable()
        }
    }

    // MARK: - Computed Properties

    private var bundledSections: [PrivacySection] {
        PrivacyPolicyDataProvider.sections(for: currentJurisdiction)
    }

    private var serverSections: [PrivacySection] {
        guard let serverPrivacyContent else { return [] }
        return serverPrivacyContent.sections.map { section in
            PrivacySection(
                id: section.id,
                title: section.title,
                // Backend/audit clean: render exactly what server stored/served.
                content: section.content,
                icon: section.icon ?? ""
            )
        }
    }

    /// Safety guard: only use server-driven Privacy if the server content looks "complete"
    /// compared to the bundled fallback.
    var isUsingServerContent: Bool {
        guard let serverPrivacyContent else { return false }
        guard !serverPrivacyContent.sections.isEmpty else { return false }
        return serverPrivacyContent.sections.count >= bundledSections.count
    }

    var displayedVersion: String {
        isUsingServerContent
            ? (serverPrivacyContent?.version ?? TermsVersionConstants.currentPrivacyPolicyVersion)
            : TermsVersionConstants.currentPrivacyPolicyVersion
    }

    var displayedEffectiveDateISO: String? {
        isUsingServerContent ? serverPrivacyContent?.effectiveDate : nil
    }

    var displayedLastUpdatedText: String {
        if let iso = displayedEffectiveDateISO,
           let formatted = ISO8601DisplayDateFormatter.formattedDateOrNil(from: iso) {
            return formatted
        }
        return isAmericanVersion ? "December 2024" : "Dezember 2024"
    }

    var sections: [PrivacySection] {
        isUsingServerContent ? serverSections : bundledSections
    }

    var filteredSections: [PrivacySection] {
        guard !searchQuery.isEmpty else { return sections }
        let query = searchQuery.lowercased()
        return sections.filter { section in
            section.title.lowercased().contains(query) ||
            section.content.lowercased().contains(query)
        }
    }

    var hasNoSearchResults: Bool {
        !searchQuery.isEmpty && filteredSections.isEmpty
    }

    var isAmericanVersion: Bool {
        currentJurisdiction == .american
    }

    var isGermanVersion: Bool {
        currentJurisdiction == .german
    }

    // MARK: - Section Management

    func toggleSection(_ section: PrivacySection) {
        if expandedSectionIds.contains(section.id) {
            expandedSectionIds.remove(section.id)
        } else {
            expandedSectionIds.insert(section.id)
        }
    }

    func isExpanded(_ section: PrivacySection) -> Bool {
        expandedSectionIds.contains(section.id)
    }

    func expandAll() {
        expandedSectionIds = Set(sections.map(\.id))
    }

    func collapseAll() {
        expandedSectionIds.removeAll()
    }

    // MARK: - Jurisdiction Management (for testing)

    func toggleJurisdiction() {
        currentJurisdiction = (currentJurisdiction == .american) ? .german : .american
        Task { [weak self] in
            await self?.loadServerDrivenPrivacyIfAvailable()
        }
    }

    // MARK: - Server-Driven Privacy (Hybrid)

    private var languageForCurrentJurisdiction: TermsOfServiceDataProvider.Language {
        currentJurisdiction == .american ? .english : .german
    }

    private func loadServerDrivenPrivacyIfAvailable() async {
        guard let termsContentService else {
            await MainActor.run {
                self.serverPrivacyContent = nil
                self.serverContentSource = nil
            }
            return
        }

        let language = languageForCurrentJurisdiction
        let bundledCount = bundledSections.count

        // 1) Try server
        do {
            let content = try await termsContentService.fetchCurrentTerms(
                language: language,
                documentType: .privacy
            )
            let shouldUseServer = content.sections.count >= bundledCount && !content.sections.isEmpty
            await MainActor.run {
                self.serverPrivacyContent = content
                self.serverContentSource = shouldUseServer ? "server" : "server_ignored"
            }
            if shouldUseServer {
                await termsContentService.logDelivery(
                    documentType: .privacy,
                    language: language,
                    servedVersion: content.version,
                    servedHash: content.documentHash,
                    source: "server"
                )
            } else {
                await termsContentService.logDelivery(
                    documentType: .privacy,
                    language: language,
                    servedVersion: TermsVersionConstants.currentPrivacyPolicyVersion,
                    servedHash: nil,
                    source: "bundled"
                )
            }
            return
        } catch {
            // fall through
        }

        // 2) Cache fallback
        if let cached = termsContentService.getCachedTerms(language: language, documentType: .privacy) {
            let shouldUseCache = cached.sections.count >= bundledCount && !cached.sections.isEmpty
            await MainActor.run {
                self.serverPrivacyContent = cached
                self.serverContentSource = shouldUseCache ? "cache" : "cache_ignored"
            }
            if shouldUseCache {
                await termsContentService.logDelivery(
                    documentType: .privacy,
                    language: language,
                    servedVersion: cached.version,
                    servedHash: cached.documentHash,
                    source: "cache"
                )
            } else {
                await termsContentService.logDelivery(
                    documentType: .privacy,
                    language: language,
                    servedVersion: TermsVersionConstants.currentPrivacyPolicyVersion,
                    servedHash: nil,
                    source: "bundled"
                )
            }
            return
        }

        // 3) Bundled fallback
        await MainActor.run {
            self.serverPrivacyContent = nil
            self.serverContentSource = "bundled"
        }
        await termsContentService.logDelivery(
            documentType: .privacy,
            language: language,
            servedVersion: TermsVersionConstants.currentPrivacyPolicyVersion,
            servedHash: nil,
            source: "bundled"
        )
    }
}

