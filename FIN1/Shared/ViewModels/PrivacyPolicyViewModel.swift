import Combine
import Foundation

/// ViewModel for Privacy Policy view
/// Manages section expansion, search filtering, and jurisdiction-based content
@MainActor
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
            self.currentJurisdiction = PrivacyPolicyDataProvider.determineJurisdiction(
                country: currentUser.country,
                nationality: currentUser.nationality,
                isNotUSCitizen: currentUser.isNotUSCitizen
            )
        } else {
            // Default to German if no user data available
            self.currentJurisdiction = .german
        }

        Task { [weak self] in
            await self?.loadServerDrivenPrivacyIfAvailable()
        }
    }

    // MARK: - Computed Properties

    private var bundledSections: [PrivacySection] {
        PrivacyPolicyDataProvider.sections(for: self.currentJurisdiction)
    }

    private var serverSections: [PrivacySection] {
        guard let serverPrivacyContent else { return [] }
        return serverPrivacyContent.sections.map { section in
            PrivacySection(
                id: section.id,
                title: section.titleOrEmpty,
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
        return serverPrivacyContent.sections.count >= self.bundledSections.count
    }

    var displayedVersion: String {
        self.isUsingServerContent
            ? (self.serverPrivacyContent?.version ?? TermsVersionConstants.currentPrivacyPolicyVersion)
            : TermsVersionConstants.currentPrivacyPolicyVersion
    }

    var displayedEffectiveDateISO: String? {
        self.isUsingServerContent ? self.serverPrivacyContent?.effectiveDate : nil
    }

    var displayedLastUpdatedText: String {
        if let iso = displayedEffectiveDateISO,
           let formatted = ISO8601DisplayDateFormatter.formattedDateOrNil(from: iso) {
            return formatted
        }
        return self.isAmericanVersion ? "December 2024" : "Dezember 2024"
    }

    var sections: [PrivacySection] {
        self.isUsingServerContent ? self.serverSections : self.bundledSections
    }

    var filteredSections: [PrivacySection] {
        guard !self.searchQuery.isEmpty else { return self.sections }
        let query = self.searchQuery.lowercased()
        return self.sections.filter { section in
            section.title.lowercased().contains(query) ||
                section.content.lowercased().contains(query)
        }
    }

    var hasNoSearchResults: Bool {
        !self.searchQuery.isEmpty && self.filteredSections.isEmpty
    }

    var isAmericanVersion: Bool {
        self.currentJurisdiction == .american
    }

    var isGermanVersion: Bool {
        self.currentJurisdiction == .german
    }

    // MARK: - Section Management

    func toggleSection(_ section: PrivacySection) {
        if self.expandedSectionIds.contains(section.id) {
            self.expandedSectionIds.remove(section.id)
        } else {
            self.expandedSectionIds.insert(section.id)
        }
    }

    func isExpanded(_ section: PrivacySection) -> Bool {
        self.expandedSectionIds.contains(section.id)
    }

    func expandAll() {
        self.expandedSectionIds = Set(self.sections.map(\.id))
    }

    func collapseAll() {
        self.expandedSectionIds.removeAll()
    }

    // MARK: - Jurisdiction Management (for testing)

    func toggleJurisdiction() {
        self.currentJurisdiction = (self.currentJurisdiction == .american) ? .german : .american
        Task { [weak self] in
            await self?.loadServerDrivenPrivacyIfAvailable()
        }
    }

    // MARK: - Server-Driven Privacy (Hybrid)

    private var languageForCurrentJurisdiction: TermsOfServiceDataProvider.Language {
        self.currentJurisdiction == .american ? .english : .german
    }

    private func loadServerDrivenPrivacyIfAvailable() async {
        guard let termsContentService else {
            await MainActor.run {
                self.serverPrivacyContent = nil
                self.serverContentSource = nil
            }
            return
        }

        let language = self.languageForCurrentJurisdiction
        let bundledCount = self.bundledSections.count

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

