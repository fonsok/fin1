import Foundation
import UIKit

// MARK: - PDF Drawing Components
struct PDFDrawingComponents {

    // MARK: - Header Drawing
    static func drawHeader(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        // Company header
        let companyText = PDFCompanyInfo.companyName
        let companyAttributes = PDFTextAttributes.titleAttributes()
        let companySize = companyText.size(withAttributes: companyAttributes)

        companyText.draw(at: CGPoint(x: PDFStyling.margin, y: y), withAttributes: companyAttributes)
        y += companySize.height + 10

        // Draw company details
        let companyDetailsAttributes = PDFTextAttributes.secondaryBodyAttributes()

        for detail in PDFCompanyInfo.companyDetails {
            detail.draw(at: CGPoint(x: PDFStyling.margin, y: y), withAttributes: companyDetailsAttributes)
            y += PDFStyling.bodyFont.lineHeight + 2
        }

        y += 20 // Add space before title

        // Invoice title
        let titleText = "Wertpapierabrechnung"
        let titleAttributes = PDFTextAttributes.headerAttributes()
        let titleSize = titleText.size(withAttributes: titleAttributes)
        titleText.draw(at: CGPoint(x: PDFStyling.margin, y: y), withAttributes: titleAttributes)
        y += titleSize.height + 5

        // Invoice number
        let invoiceNumberText = "Rechnungsnummer: \(invoice.formattedInvoiceNumber)"
        let invoiceNumberAttributes = PDFTextAttributes.tertiaryBodyAttributes()
        invoiceNumberText.draw(at: CGPoint(x: PDFStyling.margin, y: y), withAttributes: invoiceNumberAttributes)
        y += 20

        // Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale(identifier: "de_DE")
        let dateText = "Datum: \(dateFormatter.string(from: invoice.createdAt))"
        dateText.draw(at: CGPoint(x: PDFStyling.margin, y: y), withAttributes: invoiceNumberAttributes)
        y += 20

        // QR Code in top right
        y = self.drawQRCode(in: context, invoice: invoice, pageRect: pageRect, currentY: y)

        return y
    }

    // MARK: - Customer Info Drawing
    static func drawCustomerInfo(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        // Customer header
        let customerHeaderText = "Rechnungsempfänger"
        let customerHeaderAttributes = PDFTextAttributes.headerAttributes()
        customerHeaderText.draw(at: CGPoint(x: PDFStyling.margin, y: y), withAttributes: customerHeaderAttributes)
        y += 20

        // Customer details
        let customerDetails = [
            invoice.customerInfo.name,
            invoice.customerInfo.address,
            "\(invoice.customerInfo.postalCode) \(invoice.customerInfo.city)",
            "",
            "Steuernummer: \(invoice.customerInfo.taxNumber)",
            "Kundennummer: \(invoice.customerInfo.customerNumber)",
            "Depotnummer: \(invoice.customerInfo.depotNumber)",
            "Bank: \(invoice.customerInfo.bank)"
        ]

        let customerAttributes = PDFTextAttributes.bodyAttributes()

        for detail in customerDetails {
            if !detail.isEmpty {
                detail.draw(at: CGPoint(x: PDFStyling.margin, y: y), withAttributes: customerAttributes)
                y += 15
            } else {
                y += 5
            }
        }

        return y
    }

    // MARK: - Invoice Details Drawing
    static func drawInvoiceDetails(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        // Transaction details header
        let detailsHeaderText = "Transaktionsdetails"
        let detailsHeaderAttributes = PDFTextAttributes.headerAttributes()
        detailsHeaderText.draw(at: CGPoint(x: PDFStyling.margin, y: y), withAttributes: detailsHeaderAttributes)
        y += 20

        // Transaction type
        let transactionTypeText = "Art: \(invoice.type.displayName)"
        let transactionAttributes = PDFTextAttributes.bodyAttributes()
        transactionTypeText.draw(at: CGPoint(x: PDFStyling.margin, y: y), withAttributes: transactionAttributes)
        y += 15

        // Trade/Order references
        if let tradeId = invoice.tradeId {
            let tradeText = "Trade-ID: \(tradeId)"
            tradeText.draw(at: CGPoint(x: PDFStyling.margin, y: y), withAttributes: transactionAttributes)
            y += 15
        }

        if let orderId = invoice.orderId {
            let orderText = "Order-ID: \(orderId)"
            orderText.draw(at: CGPoint(x: PDFStyling.margin, y: y), withAttributes: transactionAttributes)
            y += 15
        }

        return y
    }

    // MARK: - Items Table Drawing
    static func drawItemsTable(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        let contentWidth = pageRect.width - (PDFStyling.margin * 2)
        var y = currentY

        // Draw table header background
        context.setFillColor(PDFStyling.headerBackgroundColor.cgColor)
        context.fill(CGRect(x: PDFStyling.margin, y: y, width: contentWidth, height: PDFStyling.headerHeight))

        // Draw table header text
        let headerAttributes = PDFTextAttributes.headerAttributes()
        let columnWidths = PDFTableConfig.columnWidths(for: contentWidth)
        var x = PDFStyling.margin

        for (index, title) in PDFTableConfig.columnTitles.enumerated() {
            title.draw(in: CGRect(x: x + 5, y: y + 5, width: columnWidths[index] - 10, height: PDFStyling.headerHeight - 10),
                       withAttributes: headerAttributes)
            x += columnWidths[index]
        }

        y += PDFStyling.headerHeight

        // Draw table rows
        let rowAttributes = PDFTextAttributes.bodyAttributes()

        for (index, item) in invoice.items.enumerated() {
            // Alternate row background
            if index % 2 == 0 {
                context.setFillColor(PDFStyling.alternateRowBackgroundColor.cgColor)
                context.fill(CGRect(x: PDFStyling.margin, y: y, width: contentWidth, height: PDFStyling.rowHeight))
            }

            x = PDFStyling.margin
            let rowData = [
                item.description,
                item.quantity.formattedAsLocalizedInteger(),
                item.unitPrice.formattedAsLocalizedCurrency(),
                item.totalAmount.formattedAsLocalizedCurrency(),
                item.itemType.displayName
            ]

            for (colIndex, data) in rowData.enumerated() {
                data.draw(in: CGRect(x: x + 5, y: y + 5, width: columnWidths[colIndex] - 10, height: PDFStyling.rowHeight - 10),
                          withAttributes: rowAttributes)
                x += columnWidths[colIndex]
            }

            y += PDFStyling.rowHeight
        }

        return y
    }

    // MARK: - Totals Drawing
    static func drawTotals(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        // Draw totals section
        let totalsX = pageRect.width - PDFStyling.margin - PDFStyling.totalsWidth

        // Subtotal
        let subtotalText = "Zwischensumme: \(invoice.formattedSubtotal)"
        let subtotalAttributes = PDFTextAttributes.bodyAttributes()
        subtotalText.draw(at: CGPoint(x: totalsX, y: y), withAttributes: subtotalAttributes)
        y += 20

        // Tax (if applicable)
        if invoice.totalTax > 0 {
            let taxText = "Steuer: \(invoice.formattedTaxAmount)"
            taxText.draw(at: CGPoint(x: totalsX, y: y), withAttributes: subtotalAttributes)
            y += 20
        }

        // Total
        let totalText = "Gesamtbetrag: \(invoice.formattedTotalAmount)"
        let totalAttributes = PDFTextAttributes.headerAttributes()
        totalText.draw(at: CGPoint(x: totalsX, y: y), withAttributes: totalAttributes)

        return y
    }

    // MARK: - Footer Drawing
    static func drawFooter(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) {
        let contentWidth = pageRect.width - (PDFStyling.margin * 2)
        var y = currentY // y is mutated below (y += 20, y += 70, etc.)

        // Draw separator line
        context.setStrokeColor(PDFStyling.separatorColor.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: PDFStyling.margin, y: y))
        context.addLine(to: CGPoint(x: pageRect.width - PDFStyling.margin, y: y))
        context.strokePath()
        y += 20

        // Tax note
        if let taxNote = invoice.taxNote {
            let taxNoteAttributes = PDFTextAttributes.smallAttributes()
            let taxNoteRect = CGRect(x: PDFStyling.margin, y: y, width: contentWidth, height: 60)
            taxNote.draw(in: taxNoteRect, withAttributes: taxNoteAttributes)
            y += 70
        }

        // Legal note
        if let legalNote = invoice.legalNote {
            let legalNoteAttributes = PDFTextAttributes.smallAttributes()
            let legalNoteRect = CGRect(x: PDFStyling.margin, y: y, width: contentWidth, height: 40)
            legalNote.draw(in: legalNoteRect, withAttributes: legalNoteAttributes)
            y += 50
        }

        // Additional German legal information
        let additionalInfoAttributes = PDFTextAttributes.smallSecondaryAttributes()

        for info in PDFCompanyInfo.additionalLegalInfo {
            info.draw(at: CGPoint(x: PDFStyling.margin, y: y), withAttributes: additionalInfoAttributes)
            y += PDFStyling.smallFont.lineHeight + 2
        }
    }

    // MARK: - QR Code Drawing
    static func drawQRCode(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        let y = currentY

        // Generate QR code
        guard let qrCodeImage = QRCodeGenerator.generateInvoiceQRCode(
            for: invoice,
            size: CGSize(width: 80, height: 80)
        ) else {
            print("❌ DEBUG: Failed to generate QR code for PDF")
            return y
        }

        // Position QR code in top right
        let qrSize: CGFloat = 80
        let qrX = pageRect.width - PDFStyling.margin - qrSize
        let qrY = y - qrSize // Position above current Y

        // Draw QR code
        if let cgImage = qrCodeImage.cgImage {
            context.draw(cgImage, in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))
        }

        // Add QR code label
        let qrLabel = "QR Code"
        let qrLabelAttributes = PDFTextAttributes.smallAttributes()
        let qrLabelSize = qrLabel.size(withAttributes: qrLabelAttributes)
        let qrLabelX = qrX + (qrSize - qrLabelSize.width) / 2
        let qrLabelY = qrY - 15

        qrLabel.draw(at: CGPoint(x: qrLabelX, y: qrLabelY), withAttributes: qrLabelAttributes)

        return y
    }
}
