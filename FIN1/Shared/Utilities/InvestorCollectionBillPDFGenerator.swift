import UIKit
import PDFKit

struct InvestorCollectionBillPDFGenerator {

    // MARK: - Configuration

    /// Toggle to use improved PDF generation (default: true)
    nonisolated(unsafe) static var useImprovedGeneration: Bool = true

    static func generatePreviewImage(for document: Document) -> UIImage {
        if useImprovedGeneration {
            let pdfData = generatePDFData(for: document)
            guard let pdfDocument = PDFDocument(data: pdfData),
                  let page = pdfDocument.page(at: 0) else {
                return generateLegacyPreview(for: document)
            }

            let pageRect = page.bounds(for: .mediaBox)
            let scale: CGFloat = 0.5
            let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

            UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
            defer { UIGraphicsEndImageContext() }

            guard let context = UIGraphicsGetCurrentContext() else {
                return generateLegacyPreview(for: document)
            }

            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)

            return UIGraphicsGetImageFromCurrentImageContext() ?? generateLegacyPreview(for: document)
        }

        return generateLegacyPreview(for: document)
    }

    static func generatePDFData(for document: Document) -> Data {
        if useImprovedGeneration {
            return generateImprovedPDF(for: document)
        }

        return generateLegacyPDF(for: document)
    }

    // MARK: - Improved PDF Generation

    private static func generateImprovedPDF(for document: Document) -> Data {
        let pdfMetaData: [String: Any] = [
            kCGPDFContextCreator as String: "\(LegalIdentity.platformName) Trading App",
            kCGPDFContextAuthor as String: LegalIdentity.companyLegalName,
            kCGPDFContextTitle as String: document.name
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData

        let pageRect = CGRect(x: 0, y: 0, width: PDFStylingImproved.pageWidth, height: PDFStylingImproved.pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            context.beginPage()

            let cgContext = context.cgContext
            cgContext.setShouldAntialias(true)
            cgContext.setAllowsAntialiasing(true)
            cgContext.setShouldSmoothFonts(true)
            cgContext.interpolationQuality = .high

            drawImprovedContent(in: cgContext, document: document, pageRect: pageRect)
        }
    }

    private static func drawImprovedContent(in context: CGContext, document: Document, pageRect: CGRect) {
        var y = PDFStylingImproved.margin

        // Header
        let companyText = PDFCompanyInfo.companyName
        let companyAttributes = PDFTextAttributesImproved.titleAttributes()
        companyText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: companyAttributes)
        y += PDFStylingImproved.titleFont.lineHeight + 12

        let companyDetailsAttributes = PDFTextAttributesImproved.secondaryBodyAttributes()
        for detail in PDFCompanyInfo.companyDetails {
            detail.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: companyDetailsAttributes)
            y += PDFStylingImproved.bodyFont.lineHeight + 3
        }

        y += PDFStylingImproved.sectionSpacing

        // Title
        let titleText = "Investor Collection Bill"
        let titleAttributes = PDFTextAttributesImproved.headerAttributes()
        titleText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: titleAttributes)
        y += PDFStylingImproved.headerFont.lineHeight + 12

        // Document name
        let documentNameAttributes = PDFTextAttributesImproved.bodyAttributes()
        document.name.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: documentNameAttributes)
        y += PDFStylingImproved.bodyFont.lineHeight + PDFStylingImproved.sectionSpacing

        // Document details in table format
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: "de_DE")
        let uploaded = dateFormatter.string(from: document.uploadedAt)

        let tableData = [
            ["Status", document.status.displayName],
            ["Hochgeladen", uploaded],
            ["Dateigröße", document.formattedSize]
        ]

        y = drawInfoTable(in: context, data: tableData, pageRect: pageRect, currentY: y)

        // Footer
        y += PDFStylingImproved.sectionSpacing
        context.setStrokeColor(PDFStylingImproved.separatorColor.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: PDFStylingImproved.margin, y: y))
        context.addLine(to: CGPoint(x: pageRect.width - PDFStylingImproved.margin, y: y))
        context.strokePath()
        y += 20

        let footerAttributes = PDFTextAttributesImproved.smallAttributes()
        for info in PDFCompanyInfo.additionalLegalInfo {
            info.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: footerAttributes)
            y += PDFStylingImproved.smallFont.lineHeight + 3
        }
    }

    private static func drawInfoTable(
        in context: CGContext,
        data: [[String]],
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY
        let contentWidth = PDFStylingImproved.contentWidth
        let labelWidth = contentWidth * 0.4
        let valueWidth = contentWidth * 0.6

        let bodyAttributes = PDFTextAttributesImproved.bodyAttributes()

        for (index, row) in data.enumerated() {
            guard row.count >= 2 else { continue }

            let rowRect = CGRect(
                x: PDFStylingImproved.margin,
                y: y,
                width: contentWidth,
                height: PDFStylingImproved.tableRowHeight
            )

            if index % 2 == 0 {
                context.setFillColor(PDFStylingImproved.alternateRowBackgroundColor.cgColor)
                context.fill(rowRect)
            }

            // Label
            let label = row[0]
            label.draw(in: CGRect(
                x: PDFStylingImproved.margin + PDFStylingImproved.tableCellPadding,
                y: y + (PDFStylingImproved.tableRowHeight - PDFStylingImproved.bodyFont.lineHeight) / 2,
                width: labelWidth - (PDFStylingImproved.tableCellPadding * 2),
                height: PDFStylingImproved.bodyFont.lineHeight
            ), withAttributes: bodyAttributes)

            // Value
            let value = row[1]
            var valueAttributes = bodyAttributes
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right
            valueAttributes[.paragraphStyle] = paragraphStyle

            value.draw(in: CGRect(
                x: PDFStylingImproved.margin + labelWidth + PDFStylingImproved.tableCellPadding,
                y: y + (PDFStylingImproved.tableRowHeight - PDFStylingImproved.bodyFont.lineHeight) / 2,
                width: valueWidth - (PDFStylingImproved.tableCellPadding * 2),
                height: PDFStylingImproved.bodyFont.lineHeight
            ), withAttributes: valueAttributes)

            y += PDFStylingImproved.tableRowHeight
        }

        return y
    }

    // MARK: - Legacy PDF Generation

    private static func generateLegacyPDF(for document: Document) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            drawLegacyContent(in: ctx.cgContext, rect: bounds, document: document)
        }
    }

    private static func generateLegacyPreview(for document: Document) -> UIImage {
        let size = CGSize(width: 612, height: 792)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            drawLegacyContent(in: context.cgContext, rect: CGRect(origin: .zero, size: size), document: document)
        }
    }

    private static func drawLegacyContent(in context: CGContext, rect: CGRect, document: Document) {
        context.setFillColor(UIColor.systemBackground.cgColor)
        context.fill(rect)

        let title = "Investor Collection Bill"
        let subtitle = document.name
        let uploaded = document.uploadedAt.formatted(date: .long, time: .shortened)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
            .foregroundColor: UIColor.label
        ]

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]

        let titleRect = CGRect(x: 40, y: 80, width: rect.width - 80, height: 40)
        title.draw(in: titleRect, withAttributes: titleAttributes)

        let subtitleRect = CGRect(x: 40, y: 130, width: rect.width - 80, height: 60)
        subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)

        let details = """
        Status: \(document.status.displayName)
        Uploaded: \(uploaded)
        File Size: \(document.formattedSize)

        This preview contains placeholder data for investor documentation.
        """

        let bodyRect = CGRect(x: 60, y: 220, width: rect.width - 120, height: rect.height - 280)
        details.draw(in: bodyRect, withAttributes: bodyAttributes)
    }
}
