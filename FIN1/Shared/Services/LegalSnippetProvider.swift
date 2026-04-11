import Foundation

// MARK: - Legal Snippet Provider

enum LegalSnippetKey: String {
    case docTaxNoteSell = "doc_tax_note_sell"
    case docTaxNoteBuy = "doc_tax_note_buy"
    case docLegalNoteWphg = "doc_legal_note_wphg"
    case docTaxNoteServiceCharge = "doc_tax_note_service_charge"
    case orderLegalWarningBuy = "order_legal_warning_buy"
    case orderLegalWarningSell = "order_legal_warning_sell"
    case transactionLimitWarningBuy = "transaction_limit_warning_buy"
    case dashboardRiskNote = "dashboard_risk_note"
    case riskClass7MaxLossWarning = "riskclass7_max_loss_warning"
    case riskClass7ExperiencedOnly = "riskclass7_experienced_only"
    // Collection Bill / Trade Statement specific snippets
    case docCollectionBillReferenceInfo = "doc_collection_bill_reference_info"
    case docCollectionBillLegalDisclaimer = "doc_collection_bill_legal_disclaimer"
    case docCollectionBillFooterNote = "doc_collection_bill_footer_note"
    // Account Statement (Kontoauszug) important notices
    case accountStatementImportantNoticeDe = "account_statement_important_notice_de"
    case accountStatementImportantNoticeEn = "account_statement_important_notice_en"
}

/// Result of a snippet fetch: optional title (for section heading) and content (body text). Both are server-driven when the section exists.
struct LegalSnippetResult {
    var title: String
    var content: String
}

protocol LegalSnippetProviderProtocol {
    func text(
        for key: LegalSnippetKey,
        language: TermsOfServiceDataProvider.Language,
        documentType: LegalDocumentType,
        defaultText: String,
        placeholders: [String: String]
    ) async -> String

    /// Returns title and content for the snippet so the UI can show the server-driven heading (e.g. in AGB & Rechtstexte pflegbar). Uses defaultTitle/defaultContent when section is missing.
    func snippet(
        for key: LegalSnippetKey,
        language: TermsOfServiceDataProvider.Language,
        documentType: LegalDocumentType,
        defaultTitle: String,
        defaultContent: String,
        placeholders: [String: String]
    ) async -> LegalSnippetResult
}

struct LegalSnippetProvider: LegalSnippetProviderProtocol {
    private let termsContentService: any TermsContentServiceProtocol

    init(termsContentService: any TermsContentServiceProtocol) {
        self.termsContentService = termsContentService
    }

    func text(
        for key: LegalSnippetKey,
        language: TermsOfServiceDataProvider.Language,
        documentType: LegalDocumentType = .terms,
        defaultText: String,
        placeholders: [String: String] = [:]
    ) async -> String {
        // Try cache first
        if let cached = termsContentService.getCachedTerms(language: language, documentType: documentType),
           let section = cached.sections.first(where: { $0.id == key.rawValue }) {
            return applyPlaceholders(to: section.content, placeholders: placeholders)
        }

        // Fallback to fetch from server
        if let fetched = try? await termsContentService.fetchCurrentTerms(language: language, documentType: documentType),
           let section = fetched.sections.first(where: { $0.id == key.rawValue }) {
            return applyPlaceholders(to: section.content, placeholders: placeholders)
        }

        // Final fallback: local default text
        return applyPlaceholders(to: defaultText, placeholders: placeholders)
    }

    func snippet(
        for key: LegalSnippetKey,
        language: TermsOfServiceDataProvider.Language,
        documentType: LegalDocumentType = .terms,
        defaultTitle: String,
        defaultContent: String,
        placeholders: [String: String] = [:]
    ) async -> LegalSnippetResult {
        // Bevorzugt frisch vom Server laden, damit geänderte Überschriften/Inhalte (z. B. aus dem Admin) ankommen.
        var section: TermsContentSection?
        if let fetched = try? await termsContentService.fetchCurrentTerms(language: language, documentType: documentType),
           let s = fetched.sections.first(where: { $0.id == key.rawValue }) {
            section = s
        } else if let cached = termsContentService.getCachedTerms(language: language, documentType: documentType),
                  let s = cached.sections.first(where: { $0.id == key.rawValue }) {
            section = s
        }
        let title = section.flatMap { $0.titleOrEmpty.isEmpty ? nil : $0.titleOrEmpty } ?? defaultTitle
        let content: String
        if let raw = section?.content, !raw.isEmpty {
            content = applyPlaceholders(to: raw, placeholders: placeholders)
        } else {
            content = applyPlaceholders(to: defaultContent, placeholders: placeholders)
        }
        return LegalSnippetResult(title: title, content: content)
    }

    private func applyPlaceholders(to text: String, placeholders: [String: String]) -> String {
        placeholders.reduce(text) { partial, entry in
            partial.replacingOccurrences(of: "{{\(entry.key)}}", with: entry.value)
        }
    }
}

