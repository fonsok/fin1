import SwiftUI

struct AccountStatementImportantNoticesView: View {
    @Environment(\.appServices) private var services
    @State private var germanSnippet: LegalSnippetResult?
    @State private var englishSnippet: LegalSnippetResult?

    private var germanTitle: String { germanSnippet?.title ?? "Wichtige Hinweise" }
    private var englishTitle: String { englishSnippet?.title ?? "Important Notice" }
    private var germanParagraphs: [String] {
        guard let t = germanSnippet?.content, !t.isEmpty else { return AccountStatementNoticesText.germanParagraphs }
        return t.split(separator: "\n\n").map(String.init)
    }
    private var englishParagraphs: [String] {
        guard let t = englishSnippet?.content, !t.isEmpty else { return AccountStatementNoticesText.englishParagraphs }
        return t.split(separator: "\n\n").map(String.init)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            noticeSection(title: germanTitle, paragraphs: germanParagraphs)
            noticeSection(title: englishTitle, paragraphs: englishParagraphs)
        }
        .padding(ResponsiveDesign.spacing(20))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.sectionBackground.opacity(0.3))
        .cornerRadius(ResponsiveDesign.spacing(16))
        .task {
            guard let termsService = services?.termsContentService else { return }
            let provider = LegalSnippetProvider(termsContentService: termsService)
            let defaultDE = AccountStatementNoticesText.germanParagraphs.joined(separator: "\n\n")
            let defaultEN = AccountStatementNoticesText.englishParagraphs.joined(separator: "\n\n")

            async let deTask = provider.snippet(
                for: .accountStatementImportantNoticeDe,
                language: .german,
                documentType: .terms,
                defaultTitle: "Wichtige Hinweise",
                defaultContent: defaultDE,
                placeholders: [:]
            )
            async let enTask = provider.snippet(
                for: .accountStatementImportantNoticeEn,
                language: .german,
                documentType: .terms,
                defaultTitle: "Important Notice",
                defaultContent: defaultEN,
                placeholders: [:]
            )
            let (de, en) = await (deTask, enTask)
            germanSnippet = de
            englishSnippet = en
        }
    }

    private func noticeSection(title: String, paragraphs: [String]) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(title)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            ForEach(paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.85))
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

enum AccountStatementNoticesText {
    static var germanParagraphs: [String] {
        let vatLine = "Umsatzsteuer-ID: \(LegalIdentity.companyVatId)"
        let issuerLine = "\(LegalIdentity.companyLegalName), \(LegalIdentity.companyAddressLine)"
        return [
        "Bitte erheben Sie Einwendungen gegen einzelne Buchungen unverzüglich. Schecks, Wechsel und sonstige Lastschriften schreiben wir unter dem Vorbehalt des Eingangs gut. Der angegebene Kontostand berücksichtigt nicht die Wertstellung der Buchungen (siehe oben unter \"Valuta\").",
        "Somit können bei Verfügungen möglicherweise Zinsen für die Inanspruchnahme einer eingeräumten oder geduldeten Kontoüberziehung anfallen.",
        "Die abgerechneten Leistungen sind als Bank- oder Finanzdienstleistungen von der Umsatzsteuer befreit, sofern Umsatzsteuer nicht gesondert ausgewiesen ist. \(issuerLine). \(vatLine).",
        "Guthaben sind als Einlagen nach Maßgabe des Einlagensicherungsgesetzes entschädigungsfähig. Nähere Informationen können dem \"Informationsbogen für den Einleger\" entnommen werden."
        ]
    }

    static let englishParagraphs: [String] = [
        "Please review your statement carefully and notify us immediately of any discrepancies or unauthorized transactions.",
        "All deposits and credits are subject to final verification.",
        "The ending balance may not reflect all pending transactions or holds on funds.",
        "Overdrafts may result in fees or interest charges.",
        "We are not responsible for delays in posting or for errors unless required by law.",
        "Your account is subject to the terms and conditions governing your relationship with the bank."
    ]
}











