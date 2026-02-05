import Foundation
import PDFKit
import UIKit

// MARK: - Legal Document PDF Generator

/// Generates PDF documents from legal content (Terms of Service, Privacy Policy)
/// Uses PDFKit for client-side generation with professional formatting
final class LegalDocumentPDFGenerator {

    // MARK: - Constants

    private enum Layout {
        static let pageWidth: CGFloat = 595.0  // A4 width in points
        static let pageHeight: CGFloat = 842.0 // A4 height in points
        static let marginTop: CGFloat = 60.0
        static let marginBottom: CGFloat = 60.0
        static let marginLeft: CGFloat = 50.0
        static let marginRight: CGFloat = 50.0
        static let contentWidth: CGFloat = pageWidth - marginLeft - marginRight
        static let lineSpacing: CGFloat = 6.0
        static let paragraphSpacing: CGFloat = 12.0
        static let sectionSpacing: CGFloat = 20.0
    }

    // MARK: - Initialization

    init() {}

    // MARK: - PDF Generation

    /// Generates a PDF from legal document content
    /// - Parameters:
    ///   - content: The TermsContent to render
    ///   - documentTitle: Override title (defaults to document type)
    /// - Returns: PDF data
    func generatePDF(from content: TermsContent, documentTitle: String? = nil) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "\(LegalIdentity.platformName) App",
            kCGPDFContextAuthor: LegalIdentity.companyLegalName,
            kCGPDFContextTitle: documentTitle ?? titleForDocumentType(content.documentType),
            kCGPDFContextSubject: "Legal Document v\(content.version)"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: Layout.pageWidth, height: Layout.pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            var currentY: CGFloat = 0
            var pageNumber = 1

            // Start first page
            context.beginPage()
            currentY = Layout.marginTop

            // Draw header on first page
            currentY = drawHeader(
                in: context.cgContext,
                documentType: content.documentType,
                version: content.version,
                effectiveDate: content.effectiveDate,
                startY: currentY
            )
            currentY += Layout.sectionSpacing

            // Draw each section
            for section in content.sections {
                // Check if we need a new page
                let sectionHeight = estimateSectionHeight(section)
                if currentY + sectionHeight > Layout.pageHeight - Layout.marginBottom {
                    // Draw footer before new page
                    drawFooter(in: context.cgContext, pageNumber: pageNumber)
                    pageNumber += 1

                    context.beginPage()
                    currentY = Layout.marginTop
                }

                currentY = drawSection(
                    section,
                    in: context.cgContext,
                    startY: currentY,
                    pageNumber: &pageNumber,
                    context: context
                )
                currentY += Layout.sectionSpacing
            }

            // Draw footer on last page
            drawFooter(in: context.cgContext, pageNumber: pageNumber)
        }

        return data
    }

    // MARK: - Header Drawing

    private func drawHeader(
        in context: CGContext,
        documentType: String,
        version: String,
        effectiveDate: String?,
        startY: CGFloat
    ) -> CGFloat {
        var currentY = startY

        // Company Logo/Name
        let companyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.gray
        ]
        let companyText = LegalIdentity.companyLegalName
        let companyRect = CGRect(
            x: Layout.marginLeft,
            y: currentY,
            width: Layout.contentWidth,
            height: 14
        )
        companyText.draw(in: companyRect, withAttributes: companyAttributes)
        currentY += 20

        // Document Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let title = titleForDocumentType(documentType)
        let titleRect = CGRect(
            x: Layout.marginLeft,
            y: currentY,
            width: Layout.contentWidth,
            height: 30
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)
        currentY += 35

        // Version and Date
        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]

        var metaText = "Version \(version)"
        if let effectiveDate {
            let dateString = formatEffectiveDate(effectiveDate)
            metaText += " | Gültig ab: \(dateString)"
        }

        let metaRect = CGRect(
            x: Layout.marginLeft,
            y: currentY,
            width: Layout.contentWidth,
            height: 14
        )
        metaText.draw(in: metaRect, withAttributes: metaAttributes)
        currentY += 20

        // Separator line
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: Layout.marginLeft, y: currentY))
        context.addLine(to: CGPoint(x: Layout.pageWidth - Layout.marginRight, y: currentY))
        context.strokePath()
        currentY += 10

        return currentY
    }

    // MARK: - Section Drawing

    private func drawSection(
        _ section: TermsContentSection,
        in context: CGContext,
        startY: CGFloat,
        pageNumber: inout Int,
        context pdfContext: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var currentY = startY

        // Section Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.black
        ]

        let titleHeight = heightForText(section.title, attributes: titleAttributes, width: Layout.contentWidth)
        let titleRect = CGRect(
            x: Layout.marginLeft,
            y: currentY,
            width: Layout.contentWidth,
            height: titleHeight
        )
        section.title.draw(in: titleRect, withAttributes: titleAttributes)
        currentY += titleHeight + Layout.lineSpacing

        // Section Content
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]

        // Process content line by line to handle bullets and pagination
        let lines = processContentLines(section.content)

        for line in lines {
            let lineText = line.text
            let isBullet = line.isBullet

            let lineAttributes: [NSAttributedString.Key: Any] = isBullet ? [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ] : contentAttributes

            let lineHeight = heightForText(lineText, attributes: lineAttributes, width: Layout.contentWidth - (isBullet ? 15 : 0))

            // Check for page break
            if currentY + lineHeight > Layout.pageHeight - Layout.marginBottom {
                drawFooter(in: context, pageNumber: pageNumber)
                pageNumber += 1
                pdfContext.beginPage()
                currentY = Layout.marginTop
            }

            let lineRect = CGRect(
                x: Layout.marginLeft + (isBullet ? 15 : 0),
                y: currentY,
                width: Layout.contentWidth - (isBullet ? 15 : 0),
                height: lineHeight
            )

            if isBullet {
                // Draw bullet point
                let bulletRect = CGRect(
                    x: Layout.marginLeft,
                    y: currentY,
                    width: 15,
                    height: lineHeight
                )
                "•".draw(in: bulletRect, withAttributes: lineAttributes)
            }

            lineText.draw(in: lineRect, withAttributes: lineAttributes)
            currentY += lineHeight + Layout.lineSpacing
        }

        return currentY
    }

    // MARK: - Footer Drawing

    private func drawFooter(in context: CGContext, pageNumber: Int) {
        let footerY = Layout.pageHeight - Layout.marginBottom + 20

        // Separator line
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: Layout.marginLeft, y: footerY))
        context.addLine(to: CGPoint(x: Layout.pageWidth - Layout.marginRight, y: footerY))
        context.strokePath()

        // Page number
        let pageAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.gray
        ]

        let pageText = "Seite \(pageNumber)"
        let pageSize = pageText.size(withAttributes: pageAttributes)
        let pageRect = CGRect(
            x: Layout.pageWidth - Layout.marginRight - pageSize.width,
            y: footerY + 8,
            width: pageSize.width,
            height: pageSize.height
        )
        pageText.draw(in: pageRect, withAttributes: pageAttributes)

        // Company info
        let companyText = "\(LegalIdentity.platformName) | \(LegalIdentity.companyAddressLine)"
        let companyRect = CGRect(
            x: Layout.marginLeft,
            y: footerY + 8,
            width: Layout.contentWidth - pageSize.width - 20,
            height: 12
        )
        companyText.draw(in: companyRect, withAttributes: pageAttributes)
    }

    // MARK: - Helper Methods

    private func titleForDocumentType(_ documentType: String) -> String {
        switch documentType {
        case "terms":
            return "Allgemeine Geschäftsbedingungen"
        case "privacy":
            return "Datenschutzerklärung"
        case "imprint":
            return "Impressum"
        default:
            return "Rechtliches Dokument"
        }
    }

    private func formatEffectiveDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .long
            displayFormatter.timeStyle = .none
            displayFormatter.locale = Locale(identifier: "de_DE")
            return displayFormatter.string(from: date)
        }
        return dateString
    }

    private func heightForText(_ text: String, attributes: [NSAttributedString.Key: Any], width: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(boundingBox.height)
    }

    private func estimateSectionHeight(_ section: TermsContentSection) -> CGFloat {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ]
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]

        let titleHeight = heightForText(section.title, attributes: titleAttributes, width: Layout.contentWidth)
        let contentHeight = heightForText(section.content, attributes: contentAttributes, width: Layout.contentWidth)

        return titleHeight + contentHeight + Layout.paragraphSpacing * 2
    }

    private struct ProcessedLine {
        let text: String
        let isBullet: Bool
    }

    private func processContentLines(_ content: String) -> [ProcessedLine] {
        var result: [ProcessedLine] = []

        // Clean up markdown-style formatting
        let cleanContent = content
            .replacingOccurrences(of: "**", with: "")

        for line in cleanContent.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("- ") {
                let bulletText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                result.append(ProcessedLine(text: bulletText, isBullet: true))
            } else {
                result.append(ProcessedLine(text: trimmed, isBullet: false))
            }
        }

        return result
    }
}

// MARK: - PDF Share Helper

extension LegalDocumentPDFGenerator {

    /// Creates a shareable PDF file URL for the document
    /// - Parameters:
    ///   - content: The legal document content
    ///   - filename: Optional custom filename (without extension)
    /// - Returns: URL to the temporary PDF file
    func createShareablePDF(from content: TermsContent, filename: String? = nil) -> URL? {
        let pdfData = generatePDF(from: content)

        let defaultFilename: String
        switch content.documentType {
        case "terms":
            defaultFilename = "AGB_\(LegalIdentity.platformName)_v\(content.version)"
        case "privacy":
            defaultFilename = "Datenschutz_\(LegalIdentity.platformName)_v\(content.version)"
        case "imprint":
            defaultFilename = "Impressum_\(LegalIdentity.platformName)_v\(content.version)"
        default:
            defaultFilename = "Dokument_\(LegalIdentity.platformName)_v\(content.version)"
        }

        let actualFilename = filename ?? defaultFilename
        let sanitizedFilename = actualFilename
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(sanitizedFilename)
            .appendingPathExtension("pdf")

        do {
            try pdfData.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to write PDF to temporary file: \(error)")
            return nil
        }
    }
}
