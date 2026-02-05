import Foundation
import Combine

/// ViewModel for the Imprint (Impressum) view
/// Server-driven via `TermsContentService` with bundled fallback.
@MainActor
final class ImprintViewModel: ObservableObject {
    typealias Language = TermsOfServiceDataProvider.Language

    private let termsContentService: (any TermsContentServiceProtocol)?

    @Published var searchQuery: String = ""
    @Published var expandedSectionIds: Set<String> = []
    @Published private(set) var currentLanguage: Language = .german
    @Published private(set) var serverImprintContent: TermsContent?
    @Published private(set) var serverContentSource: String?

    init(termsContentService: (any TermsContentServiceProtocol)? = nil) {
        self.termsContentService = termsContentService

        Task { [weak self] in
            await self?.loadIfAvailable()
        }
    }

    var displayedVersion: String {
        serverImprintContent?.version ?? "1.0"
    }

    var displayedEffectiveDateISO: String? {
        serverImprintContent?.effectiveDate
    }

    var displayedLastUpdatedText: String {
        if let iso = displayedEffectiveDateISO,
           let formatted = ISO8601DisplayDateFormatter.formattedDateOrNil(from: iso) {
            return formatted
        }
        return "—"
    }

    private var serverSections: [TermsOfServiceDataProvider.TermsSection] {
        guard let serverImprintContent else { return [] }
        return serverImprintContent.sections.map { section in
            TermsOfServiceDataProvider.TermsSection(
                id: section.id,
                title: section.title,
                // Backend/audit clean: render exactly what server stored/served.
                content: section.content,
                icon: section.icon ?? ""
            )
        }
    }

    /// Bundled fallback: render from Info.plist legal identity (best-effort)
    private var bundledSections: [TermsOfServiceDataProvider.TermsSection] {
        [
            .init(
                id: "imprint",
                title: currentLanguage == .german ? "Impressum" : "Imprint",
                content: bundledImprintText(),
                icon: "building.2"
            )
        ]
    }

    var sections: [TermsOfServiceDataProvider.TermsSection] {
        // Imprint is usually short; always prefer server if present.
        if let serverImprintContent, !serverImprintContent.sections.isEmpty {
            return serverSections
        }
        return bundledSections
    }

    var filteredSections: [TermsOfServiceDataProvider.TermsSection] {
        guard !searchQuery.isEmpty else { return sections }
        let q = searchQuery.lowercased()
        return sections.filter { s in
            s.title.lowercased().contains(q) || s.content.lowercased().contains(q)
        }
    }

    var hasNoSearchResults: Bool {
        !searchQuery.isEmpty && filteredSections.isEmpty
    }

    func toggleSection(_ section: TermsOfServiceDataProvider.TermsSection) {
        if expandedSectionIds.contains(section.id) {
            expandedSectionIds.remove(section.id)
        } else {
            expandedSectionIds.insert(section.id)
        }
    }

    func isExpanded(_ section: TermsOfServiceDataProvider.TermsSection) -> Bool {
        expandedSectionIds.contains(section.id)
    }

    func expandAll() {
        expandedSectionIds = Set(sections.map(\.id))
    }

    func collapseAll() {
        expandedSectionIds.removeAll()
    }

    func toggleLanguage() {
        currentLanguage = (currentLanguage == .english) ? .german : .english
        Task { [weak self] in
            await self?.loadIfAvailable()
        }
    }

    private func bundledImprintText() -> String {
        if currentLanguage == .german {
            return """
            **Anbieter / Verantwortlicher:**
            \(LegalIdentity.companyLegalName)
            \(LegalIdentity.companyAddressLine)

            **Geschäftsführung:**
            \(LegalIdentity.companyManagement)

            **Registereintrag:**
            \(LegalIdentity.companyRegisterNumber)

            **USt-IdNr.:**
            \(LegalIdentity.companyVatId)

            **Kontakt:**
            E-Mail: \(CompanyContactInfo.email)
            Telefon: \(CompanyContactInfo.phone)
            Website: \(CompanyContactInfo.website)
            """
        }

        return """
        **Provider / Responsible entity:**
        \(LegalIdentity.companyLegalName)
        \(LegalIdentity.companyAddressLine)

        **Management:**
        \(LegalIdentity.companyManagement)

        **Register:**
        \(LegalIdentity.companyRegisterNumber)

        **VAT ID:**
        \(LegalIdentity.companyVatId)

        **Contact:**
        Email: \(CompanyContactInfo.email)
        Phone: \(CompanyContactInfo.phone)
        Website: \(CompanyContactInfo.website)
        """
    }

    private func loadIfAvailable() async {
        guard let termsContentService else {
            serverImprintContent = nil
            serverContentSource = nil
            return
        }

        // 1) Server
        do {
            let content = try await termsContentService.fetchCurrentTerms(
                language: currentLanguage,
                documentType: .imprint
            )
            serverImprintContent = content
            serverContentSource = "server"
            await termsContentService.logDelivery(
                documentType: .imprint,
                language: currentLanguage,
                servedVersion: content.version,
                servedHash: content.documentHash,
                source: "server"
            )
            return
        } catch {
            // fall through
        }

        // 2) Cache
        if let cached = termsContentService.getCachedTerms(language: currentLanguage, documentType: .imprint) {
            serverImprintContent = cached
            serverContentSource = "cache"
            await termsContentService.logDelivery(
                documentType: .imprint,
                language: currentLanguage,
                servedVersion: cached.version,
                servedHash: cached.documentHash,
                source: "cache"
            )
            return
        }

        // 3) Bundled
        serverImprintContent = nil
        serverContentSource = "bundled"
        await termsContentService.logDelivery(
            documentType: .imprint,
            language: currentLanguage,
            servedVersion: "1.0",
            servedHash: nil,
            source: "bundled"
        )
    }
}

