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

}

