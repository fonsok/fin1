import Foundation
import UIKit

// MARK: - Professional PDF Document Layout
/// DIN A4 compliant document layout following German DIN 5008 business letter standards
/// and principles of proper accounting (Grundsätze ordnungsgemäßer Buchführung - GoB)

struct PDFDocumentLayout {

    // MARK: - DIN A4 Page Dimensions (in points: 1 point = 1/72 inch)
    /// A4: 210mm × 297mm = 595.28 × 841.89 points
    static let pageWidth: CGFloat = 595.0
    static let pageHeight: CGFloat = 842.0
    static let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

    // MARK: - DIN 5008 Margins (German Business Letter Standard)
    /// Left margin: 25mm = ~70.87 points (standard for business letters)
    static let leftMargin: CGFloat = 71.0
    /// Right margin: 10mm minimum, we use 20mm = ~56.69 points for readability
    static let rightMargin: CGFloat = 57.0
    /// Top margin for first element: 10mm = ~28.35 points
    static let topMargin: CGFloat = 28.0
    /// Bottom margin: 10mm minimum
    static let bottomMargin: CGFloat = 28.0

    /// Content area width
    static let contentWidth: CGFloat = pageWidth - leftMargin - rightMargin

    // MARK: - DIN 5008 Vertical Positions (from top of page)
    /// Return address zone: 27mm from top
    static let returnAddressY: CGFloat = 76.5  // 27mm
    /// Address field start: 45mm from top (DIN 5008)
    static let addressFieldY: CGFloat = 127.5  // 45mm
    /// Address field height: 40mm (5 lines)
    static let addressFieldHeight: CGFloat = 113.4  // 40mm
    /// Info block (right side) start: same as address field
    static let infoBlockY: CGFloat = 127.5
    /// Subject line: 98.46mm from top (below address field)
    static let subjectLineY: CGFloat = 279.0  // 98.46mm
    /// Body text starts: 105mm from top
    static let bodyStartY: CGFloat = 297.6  // 105mm
    /// Footer zone: starts 267mm from top (30mm from bottom)
    static let footerY: CGFloat = 756.9  // 267mm

    // MARK: - Header Layout
    static let headerHeight: CGFloat = 85.0  // Space for logo and company info
    static let logoMaxWidth: CGFloat = 150.0
    static let logoMaxHeight: CGFloat = 50.0
    static let qrCodeSize: CGFloat = 70.0

    // MARK: - Address Field Dimensions (DIN 5008)
    /// Address window: 85mm × 45mm (standard envelope window)
    static let addressFieldWidth: CGFloat = 240.9  // 85mm
    /// Info block width (right side)
    static let infoBlockWidth: CGFloat = 180.0

    // MARK: - Table Configuration
    static let tableHeaderHeight: CGFloat = 32.0
    static let tableRowHeight: CGFloat = 26.0
    static let tableCellPadding: CGFloat = 8.0
    static let tableBorderWidth: CGFloat = 0.5

    // MARK: - Totals Section
    static let totalsWidth: CGFloat = 220.0
    static let totalsRowHeight: CGFloat = 24.0

    // MARK: - Spacing
    static let sectionSpacing: CGFloat = 20.0
    static let paragraphSpacing: CGFloat = 10.0
    static let lineSpacing: CGFloat = 4.0

    // MARK: - Footer
    static let footerHeight: CGFloat = 70.0
    static let footerLineHeight: CGFloat = 12.0
}

// MARK: - Professional Color Scheme

struct PDFColorScheme {

    // MARK: - Brand Colors
    /// Primary brand color - professional deep blue
    static let primary = UIColor(red: 0.12, green: 0.25, blue: 0.45, alpha: 1.0)
    /// Accent color for highlights
    static let accent = UIColor(red: 0.18, green: 0.40, blue: 0.65, alpha: 1.0)
    /// Success/positive amounts
    static let success = UIColor(red: 0.15, green: 0.55, blue: 0.25, alpha: 1.0)
    /// Warning/negative amounts
    static let warning = UIColor(red: 0.75, green: 0.25, blue: 0.15, alpha: 1.0)

    // MARK: - Text Colors
    static let textPrimary = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
    static let textSecondary = UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1.0)
    static let textTertiary = UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)

    // MARK: - Background Colors
    static let tableHeaderBackground = primary
    static let tableHeaderText = UIColor.white
    static let tableRowAlternate = UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1.0)
    static let totalsBackground = UIColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1.0)
    static let totalsFinalBackground = UIColor(red: 0.92, green: 0.94, blue: 0.97, alpha: 1.0)

    // MARK: - Border Colors
    static let borderLight = UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0)
    static let borderMedium = UIColor(red: 0.70, green: 0.70, blue: 0.73, alpha: 1.0)
    static let borderDark = UIColor(red: 0.50, green: 0.50, blue: 0.55, alpha: 1.0)
}

// MARK: - Professional Typography

struct PDFTypography {

    // MARK: - Font Sizes (based on professional document standards)
    static let titleSize: CGFloat = 16.0      // Document title
    static let headerSize: CGFloat = 14.0      // Section headers
    static let subheaderSize: CGFloat = 11.0   // Subsections
    static let bodySize: CGFloat = 10.0        // Body text
    static let smallSize: CGFloat = 8.0        // Fine print, footer
    static let tableHeaderSize: CGFloat = 9.0  // Table headers
    static let tableCellSize: CGFloat = 9.0    // Table content
    static let returnAddressSize: CGFloat = 7.0 // Return address line

    // MARK: - Fonts
    static var titleFont: UIFont { .boldSystemFont(ofSize: titleSize) }
    static var headerFont: UIFont { .boldSystemFont(ofSize: headerSize) }
    static var subheaderFont: UIFont { .boldSystemFont(ofSize: subheaderSize) }
    static var bodyFont: UIFont { .systemFont(ofSize: bodySize) }
    static var bodyBoldFont: UIFont { .boldSystemFont(ofSize: bodySize) }
    static var smallFont: UIFont { .systemFont(ofSize: smallSize) }
    static var tableHeaderFont: UIFont { .boldSystemFont(ofSize: tableHeaderSize) }
    static var tableCellFont: UIFont { .systemFont(ofSize: tableCellSize) }
    static var returnAddressFont: UIFont { .systemFont(ofSize: returnAddressSize) }

    // MARK: - Text Attributes

    static func titleAttributes(alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        [
            .font: titleFont,
            .foregroundColor: PDFColorScheme.textPrimary,
            .paragraphStyle: createParagraphStyle(alignment: alignment, lineSpacing: 4.0)
        ]
    }

    static func headerAttributes(alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        [
            .font: headerFont,
            .foregroundColor: PDFColorScheme.textPrimary,
            .paragraphStyle: createParagraphStyle(alignment: alignment, lineSpacing: 3.0)
        ]
    }

    static func subheaderAttributes(alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        [
            .font: subheaderFont,
            .foregroundColor: PDFColorScheme.textSecondary,
            .paragraphStyle: createParagraphStyle(alignment: alignment, lineSpacing: 2.0)
        ]
    }

    static func bodyAttributes(alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        [
            .font: bodyFont,
            .foregroundColor: PDFColorScheme.textPrimary,
            .paragraphStyle: createParagraphStyle(alignment: alignment, lineSpacing: 2.0)
        ]
    }

    static func bodyBoldAttributes(alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        [
            .font: bodyBoldFont,
            .foregroundColor: PDFColorScheme.textPrimary,
            .paragraphStyle: createParagraphStyle(alignment: alignment, lineSpacing: 2.0)
        ]
    }

    static func smallAttributes(alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        [
            .font: smallFont,
            .foregroundColor: PDFColorScheme.textTertiary,
            .paragraphStyle: createParagraphStyle(alignment: alignment, lineSpacing: 1.5)
        ]
    }

    static func tableHeaderAttributes(alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        [
            .font: tableHeaderFont,
            .foregroundColor: PDFColorScheme.tableHeaderText,
            .paragraphStyle: createParagraphStyle(alignment: alignment, lineSpacing: 0)
        ]
    }

    static func tableCellAttributes(alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        [
            .font: tableCellFont,
            .foregroundColor: PDFColorScheme.textPrimary,
            .paragraphStyle: createParagraphStyle(alignment: alignment, lineSpacing: 0)
        ]
    }

    static func returnAddressAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: returnAddressFont,
            .foregroundColor: PDFColorScheme.textTertiary,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .paragraphStyle: createParagraphStyle(alignment: .left, lineSpacing: 0)
        ]
    }

    static func totalsLabelAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: bodyFont,
            .foregroundColor: PDFColorScheme.textPrimary,
            .paragraphStyle: createParagraphStyle(alignment: .left, lineSpacing: 0)
        ]
    }

    static func totalsValueAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: bodyBoldFont,
            .foregroundColor: PDFColorScheme.textPrimary,
            .paragraphStyle: createParagraphStyle(alignment: .right, lineSpacing: 0)
        ]
    }

    static func totalsFinalAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: headerFont,
            .foregroundColor: PDFColorScheme.primary,
            .paragraphStyle: createParagraphStyle(alignment: .right, lineSpacing: 0)
        ]
    }

    // MARK: - Helper

    private static func createParagraphStyle(alignment: NSTextAlignment, lineSpacing: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineSpacing = lineSpacing
        return style
    }
}

// MARK: - Invoice Table Column Configuration

struct PDFInvoiceTableConfig {

    /// Column definitions for invoice items table
    struct Column {
        let title: String
        let widthRatio: CGFloat
        let alignment: NSTextAlignment
    }

    /// Standard invoice table columns (German)
    static let columns: [Column] = [
        Column(title: "Position", widthRatio: 0.38, alignment: .left),
        Column(title: "Menge", widthRatio: 0.10, alignment: .right),
        Column(title: "Einzelpreis", widthRatio: 0.17, alignment: .right),
        Column(title: "Betrag", widthRatio: 0.17, alignment: .right),
        Column(title: "Art", widthRatio: 0.18, alignment: .center)
    ]

    static func columnWidths(for contentWidth: CGFloat) -> [CGFloat] {
        columns.map { $0.widthRatio * contentWidth }
    }

    static var columnTitles: [String] {
        columns.map(\.title)
    }

    static var columnAlignments: [NSTextAlignment] {
        columns.map(\.alignment)
    }
}

// MARK: - Trade Statement Table Column Configuration

struct PDFTradeStatementTableConfig {

    /// Column definitions for sell transactions table
    static let sellTransactionColumns: [PDFInvoiceTableConfig.Column] = [
        PDFInvoiceTableConfig.Column(title: "Trans.-Nr.", widthRatio: 0.18, alignment: .left),
        PDFInvoiceTableConfig.Column(title: "Volumen", widthRatio: 0.14, alignment: .right),
        PDFInvoiceTableConfig.Column(title: "Preis", widthRatio: 0.14, alignment: .right),
        PDFInvoiceTableConfig.Column(title: "Marktwert", widthRatio: 0.16, alignment: .right),
        PDFInvoiceTableConfig.Column(title: "Provision", widthRatio: 0.16, alignment: .right),
        PDFInvoiceTableConfig.Column(title: "Endbetrag", widthRatio: 0.22, alignment: .right)
    ]

    static func sellColumnWidths(for contentWidth: CGFloat) -> [CGFloat] {
        sellTransactionColumns.map { $0.widthRatio * contentWidth }
    }
}

// MARK: - Info Block Field Configuration

struct PDFInfoBlockConfig {

    /// Standard info block fields for invoices (right side)
    static func invoiceInfoFields(
        invoiceNumber: String,
        date: String,
        customerNumber: String,
        depotNumber: String
    ) -> [(label: String, value: String)] {
        [
            ("Rechnungsnummer:", invoiceNumber),
            ("Datum:", date),
            ("Kundennummer:", customerNumber),
            ("Depotnummer:", depotNumber)
        ]
    }

    /// Standard info block fields for trade statements
    static func tradeStatementFields(
        tradeNumber: String,
        date: String,
        depotNumber: String,
        accountNumber: String
    ) -> [(label: String, value: String)] {
        [
            ("Trade-Nummer:", tradeNumber),
            ("Datum:", date),
            ("Depotnummer:", depotNumber),
            ("Kontonummer:", accountNumber)
        ]
    }
}
