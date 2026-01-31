import Foundation
import UIKit
import PDFKit

// MARK: - Improved PDF Core Generator
/// Professional PDF generator with improved styling and layout
struct PDFCoreGeneratorImproved {

    /// Generates a professional PDF from an invoice
    static func generatePDF(from invoice: Invoice) -> Data {
        print("🔧 DEBUG: PDFCoreGeneratorImproved.generatePDF - Starting PDF generation for invoice: \(invoice.formattedInvoiceNumber)")

        let pdfMetaData = PDFMetadata.createMetadata(for: invoice)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: PDFStylingImproved.pageWidth, height: PDFStylingImproved.pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        print("🔧 DEBUG: PDFCoreGeneratorImproved.generatePDF - Starting PDF rendering")

        let data = renderer.pdfData { context in
            context.beginPage()

            let cgContext = context.cgContext

            // Set rendering quality
            cgContext.setShouldAntialias(true)
            cgContext.setAllowsAntialiasing(true)
            cgContext.setShouldSmoothFonts(true)
            cgContext.interpolationQuality = .high

            drawInvoice(in: cgContext, invoice: invoice, pageRect: pageRect)
        }

        print("🔧 DEBUG: PDFCoreGeneratorImproved.generatePDF - PDF rendering completed, data size: \(data.count) bytes")
        return data
    }

    /// Generates a preview image of the PDF
    static func generatePreview(from invoice: Invoice) -> UIImage? {
        let pdfData = generatePDF(from: invoice)

        guard let document = PDFDocument(data: pdfData),
              let page = document.page(at: 0) else {
            return nil
        }

        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 0.5 // Scale down for preview
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )

        UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - Private Drawing Orchestration

    private static func drawInvoice(in context: CGContext, invoice: Invoice, pageRect: CGRect) {
        var currentY: CGFloat = PDFStylingImproved.margin

        // Draw header
        currentY = PDFDrawingComponentsImproved.drawHeader(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY
        )

        // Draw customer info
        currentY = PDFDrawingComponentsImproved.drawCustomerInfo(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY + PDFStylingImproved.sectionSpacing
        )

        // Draw invoice details
        currentY = PDFDrawingComponentsImproved.drawInvoiceDetails(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY + PDFStylingImproved.sectionSpacing
        )

        // Draw items table
        currentY = PDFDrawingComponentsImproved.drawItemsTable(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY + PDFStylingImproved.sectionSpacing
        )

        // Draw totals
        currentY = PDFDrawingComponentsImproved.drawTotals(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY + 15
        )

        // Draw footer with notes
        PDFDrawingComponentsImproved.drawFooter(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY + 20
        )
    }
}
