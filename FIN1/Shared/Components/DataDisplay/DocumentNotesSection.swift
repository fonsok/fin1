import SwiftUI

// MARK: - Document Notes Section
/// Wiederverwendbare Komponente für Textbereiche (Verrechnung, Steuerhinweise, Rechtliche Hinweise)
/// in allen Dokument-Views (Invoices, Collection Bills, Credit Notes)
/// Folgt DRY-Prinzip zur Vermeidung von Code-Duplikation
struct DocumentNotesSection: View {
    let accountNumber: String
    let taxNote: String?
    let legalNote: String?

    /// Standard-Steuerhinweis für Verkäufe
    /// Verwendet CalculationConstants für DRY-Compliance
    static var defaultTaxNote: String {
        "Beim Verkauf erfolgt die Besteuerung gemäß Abgeltungsteuer (dzt. \(CalculationConstants.TaxRates.capitalGainsTaxWithSoli)) auf den realisierten Gewinn. Die Steuer wird automatisch von der Bank einbehalten."
    }

    /// Standard-Rechtlicher Hinweis (erster Absatz)
    static let defaultLegalNotePart1 = "Die Versteuerung erfolgt mit Gewinnrealisierung laut aktueller Regelung (§ 20 EStG)."

    /// Standard-Rechtlicher Hinweis (zweiter Absatz)
    static let defaultLegalNotePart2 = "Diese Abrechnung erfolgt nach den Bestimmungen des Wertpapierhandelsgesetzes (WpHG) und der Wertpapierhandelsverordnung (WpDVerOV)."

    init(
        accountNumber: String,
        taxNote: String? = nil,
        legalNote: String? = nil
    ) {
        self.accountNumber = accountNumber
        self.taxNote = taxNote
        self.legalNote = legalNote
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            // Account Information Section
            accountInformationSection

            // Tax Note Section
            taxNoteSection(taxNote: taxNote ?? Self.defaultTaxNote)

            // Legal Note Section
            if let legalNote = legalNote {
                legalNoteSection(legalNote: legalNote)
            } else {
                defaultLegalNoteSection
            }
        }
    }

    // MARK: - Private Sections

    private var accountInformationSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("Die Verrechnung des Gesamtbetrags erfolgt über Ihr Konto Nr.: \(accountNumber)")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .documentSection(level: 1)
    }

    private func taxNoteSection(taxNote: String) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Steuerlicher Hinweis")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(DocumentDesignSystem.textColor)

            Text(taxNote)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .documentSection(level: 2)
    }

    private var defaultLegalNoteSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Rechtlicher Hinweis")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(DocumentDesignSystem.textColor)

            Text(Self.defaultLegalNotePart1)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(Self.defaultLegalNotePart2)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, ResponsiveDesign.spacing(4))
        }
        .documentSection(level: 3)
    }

    private func legalNoteSection(legalNote: String) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Rechtlicher Hinweis")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(DocumentDesignSystem.textColor)

            Text(legalNote)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .documentSection(level: 3)
    }
}

// MARK: - Preview
#if DEBUG
struct DocumentNotesSection_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack {
                DocumentNotesSection(
                    accountNumber: "DE12345678901234567890"
                )
                .padding()
            }
        }
        .background(DocumentDesignSystem.documentBackground)
    }
}
#endif
