import Foundation
import UIKit
import PDFKit

// MARK: - Professional Invoice PDF Generator
/// Generates DIN A4 compliant invoices following German business document standards (DIN 5008)
/// and principles of proper accounting (GoB)

struct PDFInvoiceGenerator {

    // MARK: - PDF Generation

    /// Generates a professional PDF invoice
    /// - Parameter invoice: The invoice data to generate PDF from
    /// - Returns: PDF data
    static func generatePDF(from invoice: Invoice) -> Data {
        let pdfMetaData = createMetadata(for: invoice)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData

        let renderer = UIGraphicsPDFRenderer(bounds: PDFDocumentLayout.pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            let cgContext = context.cgContext
            configureRenderingQuality(cgContext)

            drawInvoice(in: cgContext, invoice: invoice, pageRect: PDFDocumentLayout.pageRect)
        }

        return data
    }

    /// Generates a preview image of the invoice PDF
    /// - Parameter invoice: The invoice data
    /// - Returns: Preview image or nil if generation failed
    static func generatePreview(from invoice: Invoice) -> UIImage? {
        let pdfData = generatePDF(from: invoice)

        guard let document = PDFDocument(data: pdfData),
              let page = document.page(at: 0) else {
            return nil
        }

        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 0.5

        UIGraphicsBeginImageContextWithOptions(
            CGSize(width: pageRect.width * scale, height: pageRect.height * scale),
            false,
            0.0
        )
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - Private Drawing Methods

    private static func drawInvoice(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect
    ) {
        var currentY: CGFloat = PDFDocumentLayout.topMargin

        // Generate QR code for invoice verification
        let qrCodeImage = QRCodeGenerator.generateInvoiceQRCode(
            for: invoice,
            size: CGSize(width: PDFDocumentLayout.qrCodeSize, height: PDFDocumentLayout.qrCodeSize)
        )

        // 1. Header with company info and QR code
        currentY = PDFProfessionalComponents.drawHeader(
            in: context,
            pageRect: pageRect,
            qrCodeImage: qrCodeImage
        )

        // 2. Address block (left) and Info block (right)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale(identifier: "de_DE")

        let infoFields = PDFInfoBlockConfig.invoiceInfoFields(
            invoiceNumber: invoice.invoiceNumber,
            date: dateFormatter.string(from: invoice.createdAt),
            customerNumber: invoice.customerInfo.customerNumber,
            depotNumber: invoice.customerInfo.depotNumber
        )

        currentY = PDFProfessionalComponents.drawAddressAndInfoBlock(
            in: context,
            pageRect: pageRect,
            recipientName: invoice.customerInfo.name,
            recipientAddress: invoice.customerInfo.address,
            recipientCity: "\(invoice.customerInfo.postalCode) \(invoice.customerInfo.city)",
            infoFields: infoFields,
            currentY: currentY
        )

        // 3. Document title
        let documentTitle = documentTitle(for: invoice)
        let subtitle = documentSubtitle(for: invoice)

        currentY = PDFProfessionalComponents.drawDocumentTitle(
            in: context,
            pageRect: pageRect,
            title: documentTitle,
            subtitle: subtitle,
            currentY: currentY
        )

        // 4. Transaction details (if applicable)
        if invoice.tradeId != nil || invoice.orderId != nil {
            currentY = drawTransactionDetails(
                in: context,
                invoice: invoice,
                pageRect: pageRect,
                currentY: currentY
            )
        }

        // 5. Items table
        currentY = drawItemsTable(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY
        )

        // 6. Totals section
        currentY = drawTotals(
            in: context,
            invoice: invoice,
            pageRect: pageRect,
            currentY: currentY
        )

        // 7. Notes section
        currentY = PDFProfessionalComponents.drawNotesSection(
            in: context,
            pageRect: pageRect,
            taxNote: invoice.taxNote,
            legalNote: invoice.legalNote,
            currentY: currentY
        )

        // 8. Footer
        PDFProfessionalComponents.drawFooter(
            in: context,
            pageRect: pageRect,
            notes: [],
            currentY: currentY
        )
    }

    // MARK: - Invoice-Specific Drawing

    private static func drawTransactionDetails(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        // Section header
        y = PDFProfessionalComponents.drawSectionHeader(
            in: context,
            pageRect: pageRect,
            title: "Transaktionsdetails",
            currentY: y,
            showUnderline: false
        )

        // Build detail fields
        var details: [(label: String, value: String)] = [
            ("Transaktionsart:", invoice.transactionType?.displayName ?? invoice.type.displayName)
        ]

        if let tradeNumber = invoice.tradeNumber {
            details.append(("Trade-Nummer:", String(format: "%03d", tradeNumber)))
        }

        if let tradeId = invoice.tradeId {
            details.append(("Trade-ID:", tradeId))
        }

        if let orderId = invoice.orderId {
            details.append(("Order-ID:", orderId))
        }

        y = PDFProfessionalComponents.drawInfoTable(
            in: context,
            pageRect: pageRect,
            data: details,
            currentY: y,
            labelWidthRatio: 0.35
        )

        return y + PDFDocumentLayout.sectionSpacing
    }

    private static func drawItemsTable(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        // Section header
        y = PDFProfessionalComponents.drawSectionHeader(
            in: context,
            pageRect: pageRect,
            title: "Positionen",
            currentY: y,
            showUnderline: false
        )

        // Prepare row data
        let rows = invoice.items.map { item in
            [
                item.description,
                item.quantity.formattedAsLocalizedInteger(),
                item.unitPrice.formattedAsLocalizedCurrency(),
                item.totalAmount.formattedAsLocalizedCurrency(),
                item.itemType.displayName
            ]
        }

        // Draw table
        y = PDFProfessionalComponents.drawTable(
            in: context,
            pageRect: pageRect,
            columnTitles: PDFInvoiceTableConfig.columnTitles,
            columnWidths: PDFInvoiceTableConfig.columnWidths(for: PDFDocumentLayout.contentWidth),
            columnAlignments: PDFInvoiceTableConfig.columnAlignments,
            rows: rows,
            currentY: y
        )

        return y
    }

    private static func drawTotals(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var totalsItems: [(label: String, value: String, isFinal: Bool)] = [
            ("Zwischensumme:", invoice.formattedSubtotal, false)
        ]

        if invoice.totalTax > 0 {
            totalsItems.append(("Steuer:", invoice.formattedTaxAmount, false))
        }

        totalsItems.append(("Gesamtbetrag:", invoice.formattedTotalAmount, true))

        return PDFProfessionalComponents.drawTotalsSection(
            in: context,
            pageRect: pageRect,
            items: totalsItems,
            currentY: currentY
        )
    }

    // MARK: - Helpers

    private static func documentTitle(for invoice: Invoice) -> String {
        switch invoice.type {
        case .creditNote:
            return "Gutschrift"
        case .securitiesSettlement:
            return "Wertpapierabrechnung"
        case .commissionInvoice:
            return "Provisionsabrechnung"
        case .accountStatement:
            return "Kontoauszug"
        case .tradingFee:
            return "Gebührenabrechnung"
        case .platformServiceCharge:
            return "Servicegebühr"
        }
    }

    private static func documentSubtitle(for invoice: Invoice) -> String? {
        if let tradeNumber = invoice.tradeNumber {
            return "zu Trade #\(String(format: "%03d", tradeNumber))"
        }
        return nil
    }

    private static func createMetadata(for invoice: Invoice) -> [String: Any] {
        [
            kCGPDFContextCreator as String: "\(LegalIdentity.platformName) Trading App",
            kCGPDFContextAuthor as String: LegalIdentity.companyLegalName,
            kCGPDFContextTitle as String: "\(invoice.type.displayName) \(invoice.invoiceNumber)",
            kCGPDFContextSubject as String: "Invoice for \(invoice.customerInfo.name)"
        ]
    }

    private static func configureRenderingQuality(_ context: CGContext) {
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        context.setShouldSmoothFonts(true)
        context.interpolationQuality = .high
    }
}

// MARK: - PDF Generator Facade (for backwards compatibility)

extension PDFGenerator {

    /// Generates invoice PDF using the new professional layout
    static func generateProfessionalInvoicePDF(from invoice: Invoice) -> Data {
        PDFInvoiceGenerator.generatePDF(from: invoice)
    }

    /// Generates invoice preview using the new professional layout
    static func generateProfessionalInvoicePreview(from invoice: Invoice) -> UIImage? {
        PDFInvoiceGenerator.generatePreview(from: invoice)
    }
}
