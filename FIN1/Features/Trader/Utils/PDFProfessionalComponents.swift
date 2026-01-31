import Foundation
import UIKit

// MARK: - Professional PDF Drawing Components
/// DIN 5008 compliant drawing components for German business documents

struct PDFProfessionalComponents {

    // MARK: - Header with Logo and QR Code

    /// Draws the document header with company information, logo placeholder, and QR code
    /// - Returns: Y position after header
    static func drawHeader(
        in context: CGContext,
        pageRect: CGRect,
        qrCodeImage: UIImage? = nil
    ) -> CGFloat {
        var currentY = PDFDocumentLayout.topMargin

        // Draw company name (large, left side)
        let companyName = PDFCompanyInfo.companyName
        companyName.draw(
            at: CGPoint(x: PDFDocumentLayout.leftMargin, y: currentY),
            withAttributes: PDFTypography.headerAttributes()
        )
        currentY += PDFTypography.headerFont.lineHeight + 4

        // Draw company details (smaller, below company name)
        let detailsAttributes = PDFTypography.smallAttributes()
        let companyAddress = PDFCompanyInfo.companyDetails.joined(separator: " | ")
        companyAddress.draw(
            at: CGPoint(x: PDFDocumentLayout.leftMargin, y: currentY),
            withAttributes: detailsAttributes
        )
        currentY += PDFTypography.smallFont.lineHeight + 8

        // Draw QR code (top right corner) - using UIKit drawing, not CGContext
        if let qrImage = qrCodeImage {
            let qrSize = PDFDocumentLayout.qrCodeSize
            let qrX = pageRect.width - PDFDocumentLayout.rightMargin - qrSize
            let qrY = PDFDocumentLayout.topMargin

            let qrRect = CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize)
            qrImage.draw(in: qrRect)

            // QR code label
            let labelText = "Scan für Details"
            let labelAttributes = PDFTypography.smallAttributes(alignment: .center)
            let labelWidth = qrSize
            let labelRect = CGRect(
                x: qrX,
                y: qrY + qrSize + 2,
                width: labelWidth,
                height: PDFTypography.smallFont.lineHeight
            )
            labelText.draw(in: labelRect, withAttributes: labelAttributes)
        }

        // Draw separator line
        currentY += 4
        context.setStrokeColor(PDFColorScheme.borderLight.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: PDFDocumentLayout.leftMargin, y: currentY))
        context.addLine(to: CGPoint(x: pageRect.width - PDFDocumentLayout.rightMargin, y: currentY))
        context.strokePath()

        return currentY + 8
    }

    // MARK: - Return Address Line (DIN 5008)

    /// Draws the small return address line above the recipient address
    static func drawReturnAddressLine(
        in context: CGContext,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        let returnAddress = "\(PDFCompanyInfo.companyName) · \(PDFCompanyInfo.companyDetails.first ?? "")"
        let returnAddressAttributes = PDFTypography.returnAddressAttributes()

        returnAddress.draw(
            at: CGPoint(x: PDFDocumentLayout.leftMargin, y: currentY),
            withAttributes: returnAddressAttributes
        )

        return currentY + PDFTypography.returnAddressFont.lineHeight + 4
    }

    // MARK: - Address Block and Info Block (Side by Side)

    /// Draws the recipient address on the left and document info on the right (DIN 5008 layout)
    /// - Returns: Y position after address/info section
    static func drawAddressAndInfoBlock(
        in context: CGContext,
        pageRect: CGRect,
        recipientName: String,
        recipientAddress: String,
        recipientCity: String,
        infoFields: [(label: String, value: String)],
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        // Draw return address line first
        y = drawReturnAddressLine(in: context, pageRect: pageRect, currentY: y)
        y += 4

        // === LEFT SIDE: Recipient Address ===
        let addressX = PDFDocumentLayout.leftMargin
        var addressY = y

        let addressAttributes = PDFTypography.bodyAttributes()
        let addressLines = [
            recipientName,
            recipientAddress,
            recipientCity
        ]

        for line in addressLines where !line.isEmpty {
            line.draw(at: CGPoint(x: addressX, y: addressY), withAttributes: addressAttributes)
            addressY += PDFTypography.bodyFont.lineHeight + 3
        }

        // === RIGHT SIDE: Info Block ===
        let infoBlockX = pageRect.width - PDFDocumentLayout.rightMargin - PDFDocumentLayout.infoBlockWidth
        var infoY = y

        // Draw info block with light background
        let infoBlockHeight = CGFloat(infoFields.count) * (PDFTypography.bodyFont.lineHeight + 8) + 16
        let infoBlockRect = CGRect(
            x: infoBlockX - 8,
            y: infoY - 4,
            width: PDFDocumentLayout.infoBlockWidth + 8,
            height: infoBlockHeight
        )
        context.setFillColor(PDFColorScheme.totalsBackground.cgColor)
        context.fill(infoBlockRect)

        // Draw border
        context.setStrokeColor(PDFColorScheme.borderLight.cgColor)
        context.setLineWidth(0.5)
        context.stroke(infoBlockRect)

        infoY += 4  // Padding inside box

        let labelAttributes = PDFTypography.bodyAttributes()
        let valueAttributes = PDFTypography.bodyBoldAttributes(alignment: .right)

        for field in infoFields {
            // Label (left)
            field.label.draw(at: CGPoint(x: infoBlockX, y: infoY), withAttributes: labelAttributes)

            // Value (right-aligned)
            let valueWidth = PDFDocumentLayout.infoBlockWidth - 8
            let valueRect = CGRect(
                x: infoBlockX,
                y: infoY,
                width: valueWidth,
                height: PDFTypography.bodyFont.lineHeight
            )
            field.value.draw(in: valueRect, withAttributes: valueAttributes)

            infoY += PDFTypography.bodyFont.lineHeight + 8
        }

        // Return the maximum Y of both blocks
        return max(addressY, infoY) + PDFDocumentLayout.sectionSpacing
    }

    // MARK: - Document Title (Betreff)

    /// Draws the document title/subject line
    static func drawDocumentTitle(
        in context: CGContext,
        pageRect: CGRect,
        title: String,
        subtitle: String? = nil,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        // Main title (bold)
        title.draw(
            at: CGPoint(x: PDFDocumentLayout.leftMargin, y: y),
            withAttributes: PDFTypography.titleAttributes()
        )
        y += PDFTypography.titleFont.lineHeight + 4

        // Subtitle if provided
        if let subtitle = subtitle, !subtitle.isEmpty {
            subtitle.draw(
                at: CGPoint(x: PDFDocumentLayout.leftMargin, y: y),
                withAttributes: PDFTypography.subheaderAttributes()
            )
            y += PDFTypography.subheaderFont.lineHeight + 4
        }

        return y + PDFDocumentLayout.sectionSpacing
    }

    // MARK: - Section Header

    /// Draws a section header with optional underline
    static func drawSectionHeader(
        in context: CGContext,
        pageRect: CGRect,
        title: String,
        currentY: CGFloat,
        showUnderline: Bool = true
    ) -> CGFloat {
        var y = currentY

        title.draw(
            at: CGPoint(x: PDFDocumentLayout.leftMargin, y: y),
            withAttributes: PDFTypography.subheaderAttributes()
        )
        y += PDFTypography.subheaderFont.lineHeight + 4

        if showUnderline {
            context.setStrokeColor(PDFColorScheme.borderMedium.cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: PDFDocumentLayout.leftMargin, y: y))
            context.addLine(to: CGPoint(x: pageRect.width - PDFDocumentLayout.rightMargin, y: y))
            context.strokePath()
            y += 4
        }

        return y + 8
    }

    // MARK: - Professional Table Drawing

    /// Draws a professional table with header and rows
    /// - Returns: Y position after table
    static func drawTable(
        in context: CGContext,
        pageRect: CGRect,
        columnTitles: [String],
        columnWidths: [CGFloat],
        columnAlignments: [NSTextAlignment],
        rows: [[String]],
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY
        let contentWidth = PDFDocumentLayout.contentWidth

        // === TABLE HEADER ===
        let headerRect = CGRect(
            x: PDFDocumentLayout.leftMargin,
            y: y,
            width: contentWidth,
            height: PDFDocumentLayout.tableHeaderHeight
        )

        // Header background
        context.setFillColor(PDFColorScheme.tableHeaderBackground.cgColor)
        context.fill(headerRect)

        // Header text
        var x = PDFDocumentLayout.leftMargin
        for (index, title) in columnTitles.enumerated() {
            let alignment = columnAlignments[safe: index] ?? .left
            let cellRect = CGRect(
                x: x + PDFDocumentLayout.tableCellPadding,
                y: y + (PDFDocumentLayout.tableHeaderHeight - PDFTypography.tableHeaderFont.lineHeight) / 2,
                width: columnWidths[index] - (PDFDocumentLayout.tableCellPadding * 2),
                height: PDFTypography.tableHeaderFont.lineHeight
            )

            title.draw(in: cellRect, withAttributes: PDFTypography.tableHeaderAttributes(alignment: alignment))
            x += columnWidths[index]
        }

        y += PDFDocumentLayout.tableHeaderHeight

        // === TABLE ROWS ===
        for (rowIndex, row) in rows.enumerated() {
            let rowRect = CGRect(
                x: PDFDocumentLayout.leftMargin,
                y: y,
                width: contentWidth,
                height: PDFDocumentLayout.tableRowHeight
            )

            // Alternate row background
            if rowIndex % 2 == 0 {
                context.setFillColor(PDFColorScheme.tableRowAlternate.cgColor)
                context.fill(rowRect)
            }

            // Row bottom border
            context.setStrokeColor(PDFColorScheme.borderLight.cgColor)
            context.setLineWidth(PDFDocumentLayout.tableBorderWidth)
            context.move(to: CGPoint(x: PDFDocumentLayout.leftMargin, y: y + PDFDocumentLayout.tableRowHeight))
            context.addLine(
                to: CGPoint(
                    x: PDFDocumentLayout.leftMargin + contentWidth,
                    y: y + PDFDocumentLayout.tableRowHeight
                )
            )
            context.strokePath()

            // Row cells
            x = PDFDocumentLayout.leftMargin
            for (colIndex, cellData) in row.enumerated() {
                guard colIndex < columnWidths.count else { break }

                let alignment = columnAlignments[safe: colIndex] ?? .left
                let cellRect = CGRect(
                    x: x + PDFDocumentLayout.tableCellPadding,
                    y: y + (PDFDocumentLayout.tableRowHeight - PDFTypography.tableCellFont.lineHeight) / 2,
                    width: columnWidths[colIndex] - (PDFDocumentLayout.tableCellPadding * 2),
                    height: PDFTypography.tableCellFont.lineHeight
                )

                cellData.draw(in: cellRect, withAttributes: PDFTypography.tableCellAttributes(alignment: alignment))
                x += columnWidths[colIndex]
            }

            y += PDFDocumentLayout.tableRowHeight
        }

        // Table bottom border (thicker)
        context.setStrokeColor(PDFColorScheme.borderMedium.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: PDFDocumentLayout.leftMargin, y: y))
        context.addLine(to: CGPoint(x: PDFDocumentLayout.leftMargin + contentWidth, y: y))
        context.strokePath()

        return y + 4
    }

    // MARK: - Totals Section (Right-Aligned Box)

    /// Draws the totals section as a professional right-aligned box
    /// - Returns: Y position after totals
    static func drawTotalsSection(
        in context: CGContext,
        pageRect: CGRect,
        items: [(label: String, value: String, isFinal: Bool)],
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY + PDFDocumentLayout.sectionSpacing

        let totalsX = pageRect.width - PDFDocumentLayout.rightMargin - PDFDocumentLayout.totalsWidth
        let totalsHeight = CGFloat(items.count) * PDFDocumentLayout.totalsRowHeight + 16

        // Draw totals background box
        let totalsRect = CGRect(
            x: totalsX - 8,
            y: y - 4,
            width: PDFDocumentLayout.totalsWidth + 8,
            height: totalsHeight
        )
        context.setFillColor(PDFColorScheme.totalsBackground.cgColor)
        context.fill(totalsRect)

        // Draw border
        context.setStrokeColor(PDFColorScheme.borderMedium.cgColor)
        context.setLineWidth(0.5)
        context.stroke(totalsRect)

        y += 4  // Padding inside box

        for item in items {
            let labelAttributes = item.isFinal
                ? PDFTypography.bodyBoldAttributes()
                : PDFTypography.totalsLabelAttributes()
            let valueAttributes = item.isFinal
                ? PDFTypography.totalsFinalAttributes()
                : PDFTypography.totalsValueAttributes()

            // Draw highlighted background for final row
            if item.isFinal {
                let finalRowRect = CGRect(
                    x: totalsX - 4,
                    y: y - 2,
                    width: PDFDocumentLayout.totalsWidth + 4,
                    height: PDFDocumentLayout.totalsRowHeight
                )
                context.setFillColor(PDFColorScheme.totalsFinalBackground.cgColor)
                context.fill(finalRowRect)
            }

            // Label (left)
            item.label.draw(at: CGPoint(x: totalsX, y: y), withAttributes: labelAttributes)

            // Value (right-aligned)
            let valueRect = CGRect(
                x: totalsX,
                y: y,
                width: PDFDocumentLayout.totalsWidth - 4,
                height: item.isFinal ? PDFTypography.headerFont.lineHeight : PDFTypography.bodyFont.lineHeight
            )
            item.value.draw(in: valueRect, withAttributes: valueAttributes)

            y += PDFDocumentLayout.totalsRowHeight
        }

        return y + 8
    }

    // MARK: - Key-Value Info Table (for transaction details)

    /// Draws a key-value info table (label on left, value on right)
    static func drawInfoTable(
        in context: CGContext,
        pageRect: CGRect,
        data: [(label: String, value: String)],
        currentY: CGFloat,
        labelWidthRatio: CGFloat = 0.5
    ) -> CGFloat {
        var y = currentY
        let contentWidth = PDFDocumentLayout.contentWidth
        let labelWidth = contentWidth * labelWidthRatio
        let valueWidth = contentWidth * (1.0 - labelWidthRatio)

        let labelAttributes = PDFTypography.bodyAttributes()
        let valueAttributes = PDFTypography.bodyBoldAttributes(alignment: .right)

        for (index, row) in data.enumerated() {
            let rowHeight = PDFDocumentLayout.tableRowHeight
            let rowRect = CGRect(
                x: PDFDocumentLayout.leftMargin,
                y: y,
                width: contentWidth,
                height: rowHeight
            )

            // Alternate background
            if index % 2 == 0 {
                context.setFillColor(PDFColorScheme.tableRowAlternate.cgColor)
                context.fill(rowRect)
            }

            // Label
            let labelRect = CGRect(
                x: PDFDocumentLayout.leftMargin + PDFDocumentLayout.tableCellPadding,
                y: y + (rowHeight - PDFTypography.bodyFont.lineHeight) / 2,
                width: labelWidth - PDFDocumentLayout.tableCellPadding,
                height: PDFTypography.bodyFont.lineHeight
            )
            row.label.draw(in: labelRect, withAttributes: labelAttributes)

            // Value
            let valueRect = CGRect(
                x: PDFDocumentLayout.leftMargin + labelWidth + PDFDocumentLayout.tableCellPadding,
                y: y + (rowHeight - PDFTypography.bodyFont.lineHeight) / 2,
                width: valueWidth - (PDFDocumentLayout.tableCellPadding * 2),
                height: PDFTypography.bodyFont.lineHeight
            )
            row.value.draw(in: valueRect, withAttributes: valueAttributes)

            y += rowHeight
        }

        return y + 8
    }

    // MARK: - Footer Section

    /// Draws the document footer with legal information
    static func drawFooter(
        in context: CGContext,
        pageRect: CGRect,
        notes: [String] = [],
        currentY: CGFloat
    ) {
        var y = currentY

        // Separator line
        context.setStrokeColor(PDFColorScheme.borderMedium.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: PDFDocumentLayout.leftMargin, y: y))
        context.addLine(to: CGPoint(x: pageRect.width - PDFDocumentLayout.rightMargin, y: y))
        context.strokePath()
        y += 12

        // Notes (if any)
        let notesAttributes = PDFTypography.smallAttributes()
        for note in notes where !note.isEmpty {
            let noteRect = CGRect(
                x: PDFDocumentLayout.leftMargin,
                y: y,
                width: PDFDocumentLayout.contentWidth,
                height: 60
            )
            note.draw(in: noteRect, withAttributes: notesAttributes)
            y += 65
        }

        // Legal information at bottom
        let legalY = pageRect.height - PDFDocumentLayout.bottomMargin - PDFDocumentLayout.footerHeight
        var footerY = max(y + 20, legalY)

        // Draw footer separator
        context.setStrokeColor(PDFColorScheme.borderLight.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: PDFDocumentLayout.leftMargin, y: footerY))
        context.addLine(to: CGPoint(x: pageRect.width - PDFDocumentLayout.rightMargin, y: footerY))
        context.strokePath()
        footerY += 8

        // Legal info lines
        let footerAttributes = PDFTypography.smallAttributes(alignment: .center)
        let footerLines = PDFCompanyInfo.additionalLegalInfo

        for line in footerLines {
            let lineRect = CGRect(
                x: PDFDocumentLayout.leftMargin,
                y: footerY,
                width: PDFDocumentLayout.contentWidth,
                height: PDFDocumentLayout.footerLineHeight
            )
            line.draw(in: lineRect, withAttributes: footerAttributes)
            footerY += PDFDocumentLayout.footerLineHeight + 2
        }
    }

    // MARK: - Notes Section (above footer)

    /// Draws optional notes section (tax notes, legal notes)
    static func drawNotesSection(
        in context: CGContext,
        pageRect: CGRect,
        taxNote: String?,
        legalNote: String?,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY + PDFDocumentLayout.sectionSpacing

        let notesAttributes = PDFTypography.smallAttributes()
        let contentWidth = PDFDocumentLayout.contentWidth

        // Tax note
        if let taxNote = taxNote, !taxNote.isEmpty {
            "Steuerhinweis:".draw(
                at: CGPoint(x: PDFDocumentLayout.leftMargin, y: y),
                withAttributes: PDFTypography.smallAttributes()
            )
            y += PDFTypography.smallFont.lineHeight + 2

            let taxNoteRect = CGRect(
                x: PDFDocumentLayout.leftMargin,
                y: y,
                width: contentWidth,
                height: 40
            )
            taxNote.draw(in: taxNoteRect, withAttributes: notesAttributes)
            y += 45
        }

        // Legal note
        if let legalNote = legalNote, !legalNote.isEmpty {
            "Rechtlicher Hinweis:".draw(
                at: CGPoint(x: PDFDocumentLayout.leftMargin, y: y),
                withAttributes: PDFTypography.smallAttributes()
            )
            y += PDFTypography.smallFont.lineHeight + 2

            let legalNoteRect = CGRect(
                x: PDFDocumentLayout.leftMargin,
                y: y,
                width: contentWidth,
                height: 40
            )
            legalNote.draw(in: legalNoteRect, withAttributes: notesAttributes)
            y += 45
        }

        return y
    }
}

