import Combine
import Foundation

/// ViewModel for Terms of Service view
/// Manages section expansion, search filtering, and language selection
@MainActor
final class TermsOfServiceViewModel: ObservableObject {

    // MARK: - Type Aliases

    typealias Language = TermsOfServiceDataProvider.Language
    typealias TermsSection = TermsOfServiceDataProvider.TermsSection

    // MARK: - Dependencies

    private let configurationService: any ConfigurationServiceProtocol
    private let termsContentService: (any TermsContentServiceProtocol)?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties

    @Published var searchQuery = ""
    @Published var expandedSectionIds: Set<String> = []
    @Published var scrollToSectionId: String?
    @Published private(set) var currentLanguage: Language = .english
    @Published private(set) var serverTermsContent: TermsContent?
    @Published private(set) var serverContentSource: String?

    // MARK: - Initialization

    init(
        configurationService: any ConfigurationServiceProtocol,
        termsContentService: (any TermsContentServiceProtocol)? = nil
    ) {
        self.configurationService = configurationService
        self.termsContentService = termsContentService

        // Observe commission rate changes from ConfigurationService
        // Cast to concrete type to access @Published property publisher
        if let concreteService = configurationService as? ConfigurationService {
            concreteService.$traderCommissionRate
                .dropFirst() // Skip initial value
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &self.cancellables)
        }

        Task { [weak self] in
            await self?.loadServerDrivenTermsIfAvailable()
        }
    }

    // MARK: - Computed Properties

    private var commissionRate: Double {
        self.configurationService.effectiveCommissionRate
    }

    private var bundledSections: [TermsSection] {
        TermsOfServiceDataProvider.sections(for: self.currentLanguage, commissionRate: self.commissionRate)
    }

    private var serverSections: [TermsSection] {
        guard let serverTermsContent else { return [] }
        return serverTermsContent.sections.map { section in
            TermsSection(
                id: section.id,
                title: section.titleOrEmpty,
                // Backend/audit clean: render exactly what server stored/served.
                content: section.content,
                icon: section.icon ?? ""
            )
        }
    }

    /// Safety guard: only use server-driven Terms if the server content looks "complete"
    /// compared to the bundled fallback. This prevents a minimal/seed server doc from
    /// wiping the user's full Terms section list.
    var isUsingServerContent: Bool {
        guard let serverTermsContent else { return false }
        guard !serverTermsContent.sections.isEmpty else { return false }
        return serverTermsContent.sections.count >= self.bundledSections.count
    }

    var displayedVersion: String {
        self.isUsingServerContent ? (self.serverTermsContent?.version ?? TermsVersionConstants.currentTermsVersion) : TermsVersionConstants.currentTermsVersion
    }

    var displayedEffectiveDateISO: String? {
        self.isUsingServerContent ? self.serverTermsContent?.effectiveDate : nil
    }

    var displayedLastUpdatedText: String {
        if let iso = displayedEffectiveDateISO,
           let formatted = ISO8601DisplayDateFormatter.formattedDateOrNil(from: iso) {
            return formatted
        }
        // Bundled fallback text
        return self.currentLanguage == .english ? "December 2024" : "Dezember 2024"
    }

    var sections: [TermsSection] {
        self.isUsingServerContent ? self.serverSections : self.bundledSections
    }

    var filteredSections: [TermsSection] {
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

    // MARK: - Section Management

    func toggleSection(_ section: TermsSection) {
        if self.expandedSectionIds.contains(section.id) {
            self.expandedSectionIds.remove(section.id)
        } else {
            self.expandedSectionIds.insert(section.id)
        }
    }

    func isExpanded(_ section: TermsSection) -> Bool {
        self.expandedSectionIds.contains(section.id)
    }

    func expandAll() {
        self.expandedSectionIds = Set(self.sections.map(\.id))
    }

    func collapseAll() {
        self.expandedSectionIds.removeAll()
    }

    // MARK: - Language Management

    func toggleLanguage() {
        self.currentLanguage = (self.currentLanguage == .english) ? .german : .english
        Task { [weak self] in
            await self?.loadServerDrivenTermsIfAvailable()
        }
    }

    // MARK: - Server-Driven Terms (Hybrid)

    private func loadServerDrivenTermsIfAvailable() async {
        guard let termsContentService else {
            await MainActor.run {
                self.serverTermsContent = nil
                self.serverContentSource = nil
            }
            return
        }

        let bundledCount = self.bundledSections.count

        // 1) Try server
        do {
            let content = try await termsContentService.fetchCurrentTerms(
                language: self.currentLanguage,
                documentType: .terms
            )
            let shouldUseServer = content.sections.count >= bundledCount && !content.sections.isEmpty
            await MainActor.run {
                self.serverTermsContent = content
                self.serverContentSource = shouldUseServer ? "server" : "server_ignored"
            }
            if shouldUseServer {
                await termsContentService.logDelivery(
                    documentType: .terms,
                    language: self.currentLanguage,
                    servedVersion: content.version,
                    servedHash: content.documentHash,
                    source: "server"
                )
            } else {
                // We fetched server content but are displaying bundled fallback.
                await termsContentService.logDelivery(
                    documentType: .terms,
                    language: self.currentLanguage,
                    servedVersion: TermsVersionConstants.currentTermsVersion,
                    servedHash: nil,
                    source: "bundled"
                )
            }
            return
        } catch {
            // fall through to cache/bundled
        }

        // 2) Cache fallback
        if let cached = termsContentService.getCachedTerms(language: currentLanguage, documentType: .terms) {
            let shouldUseCache = cached.sections.count >= bundledCount && !cached.sections.isEmpty
            await MainActor.run {
                self.serverTermsContent = cached
                self.serverContentSource = shouldUseCache ? "cache" : "cache_ignored"
            }
            if shouldUseCache {
                await termsContentService.logDelivery(
                    documentType: .terms,
                    language: self.currentLanguage,
                    servedVersion: cached.version,
                    servedHash: cached.documentHash,
                    source: "cache"
                )
            } else {
                await termsContentService.logDelivery(
                    documentType: .terms,
                    language: self.currentLanguage,
                    servedVersion: TermsVersionConstants.currentTermsVersion,
                    servedHash: nil,
                    source: "bundled"
                )
            }
            return
        }

        // 3) Bundled fallback (still log version for audit trail)
        await MainActor.run {
            self.serverTermsContent = nil
            self.serverContentSource = "bundled"
        }
        await termsContentService.logDelivery(
            documentType: .terms,
            language: self.currentLanguage,
            servedVersion: TermsVersionConstants.currentTermsVersion,
            servedHash: nil,
            source: "bundled"
        )
    }
}
