import Foundation
import PDFKit
import UIKit

// MARK: - PDF Core Generator
struct PDFCoreGenerator {

    /// Generates a PDF from an invoice
    static func generatePDF(from invoice: Invoice) -> Data {
        print("🔧 DEBUG: PDFCoreGenerator.generatePDF - Starting PDF generation for invoice: \(invoice.formattedInvoiceNumber)")

        let pdfMetaData = PDFMetadata.createMetadata(for: invoice)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: PDFStyling.pageWidth, height: PDFStyling.pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        print("🔧 DEBUG: PDFCoreGenerator.generatePDF - Starting PDF rendering")

        let data = renderer.pdfData { context in
            context.beginPage()

            let cgContext = context.cgContext
            self.drawInvoice(in: cgContext, invoice: invoice, pageRect: pageRect)
        }

        print("🔧 DEBUG: PDFCoreGenerator.generatePDF - PDF rendering completed, data size: \(data.count) bytes")
        return data
    }

    /// Generates a preview image of the PDF
    static func generatePreview(from invoice: Invoice) -> UIImage? {
        let pdfData = self.generatePDF(from: invoice)

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
        var currentY: CGFloat = PDFStyling.margin

        // Draw header
        currentY = PDFDrawingComponents.drawHeader(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY
        )

        // Draw customer info
        currentY = PDFDrawingComponents.drawCustomerInfo(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY + 20
        )

        // Draw invoice details
        currentY = PDFDrawingComponents.drawInvoiceDetails(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY + 20
        )

        // Draw items table
        currentY = PDFDrawingComponents.drawItemsTable(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY + 20
        )

        // Draw totals
        currentY = PDFDrawingComponents.drawTotals(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY + 20
        )

        // Draw footer with notes
        PDFDrawingComponents.drawFooter(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY + 20
        )
    }
}
