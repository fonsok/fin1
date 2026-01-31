import Foundation
import UIKit

// MARK: - Improved PDF Drawing Components
/// Professional PDF drawing components with improved styling and layout
struct PDFDrawingComponentsImproved {

    // MARK: - Header Drawing
    static func drawHeader(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        // Draw logo (if available) - placeholder for now
        // TODO: Add actual logo image when available
        /*
        if let logoImage = UIImage(named: LegalIdentity.logoAssetName) {
            let logoRect = CGRect(
                x: PDFStylingImproved.margin,
                y: y,
                width: min(logoImage.size.width, PDFStylingImproved.logoMaxWidth),
                height: min(logoImage.size.height, PDFStylingImproved.logoMaxHeight)
            )
            logoImage.draw(in: logoRect)
            y += logoRect.height + 15
        }
        */

        // Company header with improved styling
        let companyText = PDFCompanyInfo.companyName
        let companyAttributes = PDFTextAttributesImproved.titleAttributes()
        let companySize = companyText.size(withAttributes: companyAttributes)

        companyText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: companyAttributes)
        y += companySize.height + 12

        // Draw company details with better spacing
        let companyDetailsAttributes = PDFTextAttributesImproved.secondaryBodyAttributes()

        for detail in PDFCompanyInfo.companyDetails {
            detail.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: companyDetailsAttributes)
            y += PDFStylingImproved.bodyFont.lineHeight + 3
        }

        y += PDFStylingImproved.sectionSpacing

        // Invoice title with improved styling
        let titleText = "Wertpapierabrechnung"
        let titleAttributes = PDFTextAttributesImproved.headerAttributes()
        let titleSize = titleText.size(withAttributes: titleAttributes)
        titleText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: titleAttributes)
        y += titleSize.height + 8

        // Invoice number and date in a more compact layout
        let infoAttributes = PDFTextAttributesImproved.bodyAttributes()
        let invoiceNumberText = "Rechnungsnummer: \(invoice.formattedInvoiceNumber)"
        invoiceNumberText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: infoAttributes)

        // Date on the same line, right-aligned
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale(identifier: "de_DE")
        let dateText = "Datum: \(dateFormatter.string(from: invoice.createdAt))"
        let dateSize = dateText.size(withAttributes: infoAttributes)
        dateText.draw(at: CGPoint(x: pageRect.width - PDFStylingImproved.margin - dateSize.width, y: y), withAttributes: infoAttributes)

        y += PDFStylingImproved.bodyFont.lineHeight + 8

        // QR Code in top right (if needed)
        y = drawQRCode(in: context, invoice: invoice, pageRect: pageRect, currentY: y)

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

        // Customer header with improved styling
        let customerHeaderText = "Rechnungsempfänger"
        let customerHeaderAttributes = PDFTextAttributesImproved.subheaderAttributes()
        customerHeaderText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: customerHeaderAttributes)
        y += 18

        // Customer details with better formatting
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

        let customerAttributes = PDFTextAttributesImproved.bodyAttributes()

        for detail in customerDetails {
            if !detail.isEmpty {
                detail.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: customerAttributes)
                y += PDFStylingImproved.bodyFont.lineHeight + 4
            } else {
                y += 6
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
        let detailsHeaderAttributes = PDFTextAttributesImproved.subheaderAttributes()
        detailsHeaderText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: detailsHeaderAttributes)
        y += 18

        // Transaction type
        let transactionTypeText = "Art: \(invoice.type.displayName)"
        let transactionAttributes = PDFTextAttributesImproved.bodyAttributes()
        transactionTypeText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: transactionAttributes)
        y += PDFStylingImproved.bodyFont.lineHeight + 4

        // Trade/Order references
        if let tradeId = invoice.tradeId {
            let tradeText = "Trade-ID: \(tradeId)"
            tradeText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: transactionAttributes)
            y += PDFStylingImproved.bodyFont.lineHeight + 4
        }

        if let orderId = invoice.orderId {
            let orderText = "Order-ID: \(orderId)"
            orderText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: transactionAttributes)
            y += PDFStylingImproved.bodyFont.lineHeight + 4
        }

        return y
    }

    // MARK: - Improved Items Table Drawing
    static func drawItemsTable(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        let contentWidth = PDFStylingImproved.contentWidth
        var y = currentY

        // Draw table header with professional styling
        let headerRect = CGRect(
            x: PDFStylingImproved.margin,
            y: y,
            width: contentWidth,
            height: PDFStylingImproved.tableHeaderHeight
        )

        // Header background with brand color
        context.setFillColor(PDFStylingImproved.tableHeaderBackgroundColor.cgColor)
        context.fill(headerRect)

        // Draw header border
        context.setStrokeColor(PDFStylingImproved.tableHeaderBackgroundColor.cgColor)
        context.setLineWidth(PDFStylingImproved.tableBorderWidth)
        context.stroke(headerRect)

        // Draw table header text
        let headerAttributes = PDFTextAttributesImproved.tableHeaderAttributes()
        let columnWidths = PDFTableConfigImproved.columnWidths(for: contentWidth)
        var x = PDFStylingImproved.margin

        for (index, title) in PDFTableConfigImproved.columnTitles.enumerated() {
            let alignment = PDFTableConfigImproved.columnAlignments[index]
            let textRect = CGRect(
                x: x + PDFStylingImproved.tableCellPadding,
                y: y + (PDFStylingImproved.tableHeaderHeight - PDFStylingImproved.tableHeaderFont.lineHeight) / 2,
                width: columnWidths[index] - (PDFStylingImproved.tableCellPadding * 2),
                height: PDFStylingImproved.tableHeaderFont.lineHeight
            )

            // Create attributed string with proper alignment
            let attributedTitle = NSMutableAttributedString(string: title, attributes: headerAttributes)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = alignment
            attributedTitle.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: title.count))

            attributedTitle.draw(in: textRect)
            x += columnWidths[index]
        }

        y += PDFStylingImproved.tableHeaderHeight

        // Draw table rows with improved styling
        let rowAttributes = PDFTextAttributesImproved.tableCellAttributes()

        for (index, item) in invoice.items.enumerated() {
            let rowRect = CGRect(
                x: PDFStylingImproved.margin,
                y: y,
                width: contentWidth,
                height: PDFStylingImproved.tableRowHeight
            )

            // Alternate row background
            if index % 2 == 0 {
                context.setFillColor(PDFStylingImproved.alternateRowBackgroundColor.cgColor)
                context.fill(rowRect)
            }

            // Draw row border
            context.setStrokeColor(PDFStylingImproved.separatorColor.cgColor)
            context.setLineWidth(PDFStylingImproved.tableBorderWidth)
            context.stroke(rowRect)

            x = PDFStylingImproved.margin
            let rowData = [
                item.description,
                item.quantity.formattedAsLocalizedInteger(),
                item.unitPrice.formattedAsLocalizedCurrency(),
                item.totalAmount.formattedAsLocalizedCurrency(),
                item.itemType.displayName
            ]

            for (colIndex, data) in rowData.enumerated() {
                let alignment = PDFTableConfigImproved.columnAlignments[colIndex]
                let cellRect = CGRect(
                    x: x + PDFStylingImproved.tableCellPadding,
                    y: y + (PDFStylingImproved.tableRowHeight - PDFStylingImproved.tableFont.lineHeight) / 2,
                    width: columnWidths[colIndex] - (PDFStylingImproved.tableCellPadding * 2),
                    height: PDFStylingImproved.tableFont.lineHeight
                )

                // Create attributed string with proper alignment
                let attributedData = NSMutableAttributedString(string: data, attributes: rowAttributes)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = alignment
                attributedData.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: data.count))

                attributedData.draw(in: cellRect)
                x += columnWidths[colIndex]
            }

            y += PDFStylingImproved.tableRowHeight
        }

        // Draw bottom border
        context.setStrokeColor(PDFStylingImproved.separatorColor.cgColor)
        context.setLineWidth(PDFStylingImproved.tableBorderWidth * 2) // Thicker bottom border
        context.move(to: CGPoint(x: PDFStylingImproved.margin, y: y))
        context.addLine(to: CGPoint(x: PDFStylingImproved.margin + contentWidth, y: y))
        context.strokePath()

        return y
    }

    // MARK: - Improved Totals Drawing
    static func drawTotals(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY + 15

        // Draw totals section with better styling
        let totalsX = pageRect.width - PDFStylingImproved.margin - PDFStylingImproved.totalsWidth
        let totalsAttributes = PDFTextAttributesImproved.totalsAttributes()

        // Subtotal
        let subtotalText = "Zwischensumme:"
        let subtotalValue = invoice.formattedSubtotal
        let subtotalSize = subtotalText.size(withAttributes: totalsAttributes)
        subtotalText.draw(at: CGPoint(x: totalsX, y: y), withAttributes: totalsAttributes)
        subtotalValue.draw(at: CGPoint(x: totalsX + subtotalSize.width + 10, y: y), withAttributes: totalsAttributes)
        y += 22

        // Tax (if applicable)
        if invoice.totalTax > 0 {
            let taxText = "Steuer:"
            let taxValue = invoice.formattedTaxAmount
            let taxSize = taxText.size(withAttributes: totalsAttributes)
            taxText.draw(at: CGPoint(x: totalsX, y: y), withAttributes: totalsAttributes)
            taxValue.draw(at: CGPoint(x: totalsX + taxSize.width + 10, y: y), withAttributes: totalsAttributes)
            y += 22
        }

        // Total with emphasis
        let totalText = "Gesamtbetrag:"
        let totalValue = invoice.formattedTotalAmount
        let totalTextSize = totalText.size(withAttributes: totalsAttributes)

        // Draw total label
        totalText.draw(at: CGPoint(x: totalsX, y: y), withAttributes: totalsAttributes)

        // Draw total value with bold font
        var totalValueAttributes = totalsAttributes
        totalValueAttributes[.font] = PDFStylingImproved.headerFont
        totalValueAttributes[.foregroundColor] = PDFStylingImproved.primaryColor
        totalValue.draw(at: CGPoint(x: totalsX + totalTextSize.width + 10, y: y), withAttributes: totalValueAttributes)

        // Draw underline for total
        y += 20
        context.setStrokeColor(PDFStylingImproved.primaryColor.cgColor)
        context.setLineWidth(1.5)
        let underlineX = totalsX + totalTextSize.width + 10
        let underlineWidth = totalValue.size(withAttributes: totalValueAttributes).width
        context.move(to: CGPoint(x: underlineX, y: y))
        context.addLine(to: CGPoint(x: underlineX + underlineWidth, y: y))
        context.strokePath()

        return y
    }

    // MARK: - Improved Footer Drawing
    static func drawFooter(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) {
        let contentWidth = PDFStylingImproved.contentWidth
        var y = currentY + 20

        // Draw separator line with brand color
        context.setStrokeColor(PDFStylingImproved.separatorColor.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: PDFStylingImproved.margin, y: y))
        context.addLine(to: CGPoint(x: pageRect.width - PDFStylingImproved.margin, y: y))
        context.strokePath()
        y += 20

        // Tax note
        if let taxNote = invoice.taxNote {
            let taxNoteAttributes = PDFTextAttributesImproved.smallAttributes()
            let taxNoteRect = CGRect(x: PDFStylingImproved.margin, y: y, width: contentWidth, height: 60)
            taxNote.draw(in: taxNoteRect, withAttributes: taxNoteAttributes)
            y += 70
        }

        // Legal note
        if let legalNote = invoice.legalNote {
            let legalNoteAttributes = PDFTextAttributesImproved.smallAttributes()
            let legalNoteRect = CGRect(x: PDFStylingImproved.margin, y: y, width: contentWidth, height: 40)
            legalNote.draw(in: legalNoteRect, withAttributes: legalNoteAttributes)
            y += 50
        }

        // Additional German legal information
        let additionalInfoAttributes = PDFTextAttributesImproved.smallAttributes()

        for info in PDFCompanyInfo.additionalLegalInfo {
            info.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: additionalInfoAttributes)
            y += PDFStylingImproved.smallFont.lineHeight + 3
        }
    }

    // MARK: - QR Code Drawing
    static func drawQRCode(
        in context: CGContext,
        invoice: Invoice,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        // Generate QR code
        guard let qrCodeImage = QRCodeGenerator.generateInvoiceQRCode(
            for: invoice,
            size: CGSize(width: PDFStylingImproved.qrCodeSize, height: PDFStylingImproved.qrCodeSize)
        ) else {
            // QR code generation failed, but continue without it
            return currentY
        }

        // Position QR code in top right
        let qrSize = PDFStylingImproved.qrCodeSize
        let qrX = pageRect.width - PDFStylingImproved.margin - qrSize
        let qrY = PDFStylingImproved.margin

        // Draw QR code
        if let cgImage = qrCodeImage.cgImage {
            context.draw(cgImage, in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))
        }

        // Add QR code label
        let qrLabel = "QR Code"
        let qrLabelAttributes = PDFTextAttributesImproved.smallAttributes()
        let qrLabelSize = qrLabel.size(withAttributes: qrLabelAttributes)
        let qrLabelX = qrX + (qrSize - qrLabelSize.width) / 2
        let qrLabelY = qrY + qrSize + PDFStylingImproved.qrCodeLabelSpacing

        qrLabel.draw(at: CGPoint(x: qrLabelX, y: qrLabelY), withAttributes: qrLabelAttributes)

        return currentY
    }
}
