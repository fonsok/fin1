import Foundation
import UIKit

// MARK: - Improved PDF Styling Configuration
/// Professional styling for FIN1 PDF documents (Invoices, Collection Bills, Credit Notes)
struct PDFStylingImproved {

    // MARK: - Page Configuration
    static let pageWidth: CGFloat = 595.0  // A4 width in points (210mm)
    static let pageHeight: CGFloat = 842.0 // A4 height in points (297mm)
    static let margin: CGFloat = 60.0      // Increased margin for better readability
    static let contentWidth: CGFloat = pageWidth - (margin * 2)

    // MARK: - Professional Color Scheme
    /// Primary brand color (can be customized to match FIN1 branding)
    static let primaryColor = UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1.0) // Deep blue
    static let accentColor = UIColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0) // Light blue
    static let successColor = UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0) // Green

    /// Text colors
    static let primaryTextColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) // Almost black
    static let secondaryTextColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0) // Dark gray
    static let tertiaryTextColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) // Medium gray

    /// Background colors
    static let headerBackgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0) // Light gray
    static let tableHeaderBackgroundColor = primaryColor // Brand color for headers
    static let tableHeaderTextColor = UIColor.white
    static let alternateRowBackgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0) // Very light gray
    static let separatorColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0) // Light gray border

    // MARK: - Professional Typography
    /// Use system fonts with better sizing
    static let titleFont = UIFont.boldSystemFont(ofSize: 28) // Larger, more prominent
    static let headerFont = UIFont.boldSystemFont(ofSize: 18) // Section headers
    static let subheaderFont = UIFont.boldSystemFont(ofSize: 14) // Subsections
    static let bodyFont = UIFont.systemFont(ofSize: 11) // Body text (slightly smaller for more content)
    static let smallFont = UIFont.systemFont(ofSize: 9) // Fine print
    static let tableFont = UIFont.systemFont(ofSize: 10) // Table content
    static let tableHeaderFont = UIFont.boldSystemFont(ofSize: 11) // Table headers

    // MARK: - Spacing Configuration
    static let sectionSpacing: CGFloat = 30.0 // Space between major sections
    static let paragraphSpacing: CGFloat = 12.0 // Space between paragraphs
    static let lineSpacing: CGFloat = 4.0 // Space between lines

    // MARK: - Table Configuration
    static let tableHeaderHeight: CGFloat = 35.0 // Taller header for better visibility
    static let tableRowHeight: CGFloat = 28.0 // Slightly taller rows
    static let tableCellPadding: CGFloat = 8.0 // Padding inside cells
    static let tableBorderWidth: CGFloat = 0.5 // Thin borders
    static let totalsWidth: CGFloat = 250.0 // Width for totals section

    // MARK: - Logo Configuration
    static let logoMaxWidth: CGFloat = 150.0
    static let logoMaxHeight: CGFloat = 60.0
    static let logoTopMargin: CGFloat = 20.0

    // MARK: - QR Code Configuration
    static let qrCodeSize: CGFloat = 80.0
    static let qrCodeLabelSpacing: CGFloat = 5.0

    // MARK: - Preview Configuration
    static let previewScale: CGFloat = 0.5

    // MARK: - Info Table Configuration
    static let infoTableLabelWidthRatio: CGFloat = 0.4
    static let infoTableValueWidthRatio: CGFloat = 0.6

    // MARK: - Sell Transactions Table Column Widths
    static let sellTableColumnWidthRatios: [CGFloat] = [
        0.20,  // Transaktionsnummer
        0.15,  // Volumen
        0.15,  // Preis
        0.15,  // Marktwert
        0.15,  // Provision
        0.20   // Endbetrag
    ]
}

// MARK: - Improved PDF Text Attributes
struct PDFTextAttributesImproved {

    static func titleAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStylingImproved.titleFont,
            .foregroundColor: PDFStylingImproved.primaryColor, // Use brand color
            .paragraphStyle: self.createParagraphStyle(alignment: .left, lineSpacing: 6.0)
        ]
    }

    static func headerAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStylingImproved.headerFont,
            .foregroundColor: PDFStylingImproved.primaryTextColor,
            .paragraphStyle: self.createParagraphStyle(alignment: .left, lineSpacing: 4.0)
        ]
    }

    static func subheaderAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStylingImproved.subheaderFont,
            .foregroundColor: PDFStylingImproved.secondaryTextColor,
            .paragraphStyle: self.createParagraphStyle(alignment: .left, lineSpacing: 3.0)
        ]
    }

    static func bodyAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStylingImproved.bodyFont,
            .foregroundColor: PDFStylingImproved.primaryTextColor,
            .paragraphStyle: self.createParagraphStyle(alignment: .left, lineSpacing: PDFStylingImproved.lineSpacing)
        ]
    }

    static func secondaryBodyAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStylingImproved.bodyFont,
            .foregroundColor: PDFStylingImproved.secondaryTextColor,
            .paragraphStyle: self.createParagraphStyle(alignment: .left, lineSpacing: PDFStylingImproved.lineSpacing)
        ]
    }

    static func tableHeaderAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStylingImproved.tableHeaderFont,
            .foregroundColor: PDFStylingImproved.tableHeaderTextColor,
            .paragraphStyle: self.createParagraphStyle(alignment: .left, lineSpacing: 0)
        ]
    }

    static func tableCellAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStylingImproved.tableFont,
            .foregroundColor: PDFStylingImproved.primaryTextColor,
            .paragraphStyle: self.createParagraphStyle(alignment: .left, lineSpacing: 0)
        ]
    }

    static func smallAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStylingImproved.smallFont,
            .foregroundColor: PDFStylingImproved.tertiaryTextColor,
            .paragraphStyle: self.createParagraphStyle(alignment: .left, lineSpacing: 2.0)
        ]
    }

    static func totalsAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStylingImproved.subheaderFont,
            .foregroundColor: PDFStylingImproved.primaryTextColor,
            .paragraphStyle: self.createParagraphStyle(alignment: .right, lineSpacing: 0)
        ]
    }

    // MARK: - Helper
    private static func createParagraphStyle(alignment: NSTextAlignment, lineSpacing: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = PDFStylingImproved.paragraphSpacing
        return style
    }
}

// MARK: - Improved PDF Table Configuration
struct PDFTableConfigImproved {

    static func columnWidths(for contentWidth: CGFloat) -> [CGFloat] {
        // Better proportions for invoice table
        return [
            contentWidth * 0.35,  // Position (wider for descriptions)
            contentWidth * 0.12,  // Stück (quantity)
            contentWidth * 0.18,  // Kurs je Stück (unit price)
            contentWidth * 0.20,  // Betrag (€) (amount)
            contentWidth * 0.15   // Art (type)
        ]
    }

    static let columnTitles = ["Position", "Stück", "Kurs je Stück", "Betrag (€)", "Art"]

    /// Column alignments
    static let columnAlignments: [NSTextAlignment] = [
        .left,   // Position
        .right,  // Stück
        .right,  // Kurs je Stück
        .right,  // Betrag (€)
        .center  // Art
    ]
}

// MARK: - PDF Company Information (Re-exported from PDFStyling for convenience)
// Note: This uses the same PDFCompanyInfo from PDFStyling.swift
// If you need to customize, you can override it here
extension PDFStylingImproved {
    // Re-export PDFCompanyInfo for use in improved components
    // PDFCompanyInfo is defined in PDFStyling.swift and accessible here
}
