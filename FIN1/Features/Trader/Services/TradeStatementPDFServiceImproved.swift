import Foundation
import UIKit
import PDFKit
import OSLog

// MARK: - Improved Trade Statement PDF Service
/// Professional PDF generator for trade statements (Collection Bills) with improved styling

@MainActor
final class TradeStatementPDFServiceImproved: TradeStatementPDFServiceProtocol {

    // MARK: - Logger
    private let logger = Logger(subsystem: "com.fin1.app", category: "TradeStatementPDFService")

    // MARK: - Public Methods

    func generatePDF(for displayData: TradeStatementDisplayData, trade: TradeOverviewItem) async throws -> Data {
        logger.info("Starting PDF generation for Trade #\(trade.tradeNumber)")

        let pdfMetaData: [String: Any] = [
            kCGPDFContextCreator as String: "\(LegalIdentity.platformName) Trading App",
            kCGPDFContextAuthor as String: LegalIdentity.companyLegalName,
            kCGPDFContextTitle as String: "Collection Bill Trade \(String(format: "%03d", trade.tradeNumber))"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData

        let pageRect = CGRect(x: 0, y: 0, width: PDFStylingImproved.pageWidth, height: PDFStylingImproved.pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let pdfData = renderer.pdfData { context in
            context.beginPage()

            let cgContext = context.cgContext

            // Set rendering quality
            cgContext.setShouldAntialias(true)
            cgContext.setAllowsAntialiasing(true)
            cgContext.setShouldSmoothFonts(true)
            cgContext.interpolationQuality = .high

            drawCollectionBill(in: cgContext, displayData: displayData, trade: trade, pageRect: pageRect)
        }

        logger.info("PDF generated successfully, size: \(pdfData.count) bytes")
        return pdfData
    }

    func generatePreview(for displayData: TradeStatementDisplayData, trade: TradeOverviewItem) async throws -> UIImage {
        logger.info("Generating PDF preview for Trade #\(trade.tradeNumber)")

        let pdfData = try await generatePDF(for: displayData, trade: trade)

        guard let document = PDFDocument(data: pdfData),
              let page = document.page(at: 0) else {
            throw PDFGenerationError.previewConversionFailed
        }

        let pageRect = page.bounds(for: .mediaBox)
        let scale = PDFStylingImproved.previewScale
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )

        UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else {
            throw PDFGenerationError.previewConversionFailed
        }

        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)

        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            throw PDFGenerationError.previewConversionFailed
        }

        logger.info("PDF preview generated successfully")
        return image
    }

    func savePDFToDocuments(_ pdfData: Data, fileName: String) async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(fileName).pdf")

        try pdfData.write(to: fileURL)
        logger.info("PDF saved to \(fileURL.path)")
        return fileURL
    }

    // MARK: - Private Drawing Methods

    private func drawCollectionBill(
        in context: CGContext,
        displayData: TradeStatementDisplayData,
        trade: TradeOverviewItem,
        pageRect: CGRect
    ) {
        var currentY: CGFloat = PDFStylingImproved.margin

        // Draw header
        currentY = drawHeader(
            in: context,
            trade: trade,
            pageRect: pageRect,
            currentY: currentY
        )

        // Draw depot information
        currentY = drawDepotInfo(
            in: context,
            displayData: displayData,
            pageRect: pageRect,
            currentY: currentY + PDFStylingImproved.sectionSpacing
        )

        // Draw buy transaction
        if let buyTransaction = displayData.buyTransaction {
            currentY = drawBuyTransaction(
                in: context,
                buyTransaction: buyTransaction,
                displayData: displayData,
                pageRect: pageRect,
                currentY: currentY + PDFStylingImproved.sectionSpacing
            )
        }

        // Draw sell transactions
        if !displayData.sellTransactions.isEmpty {
            currentY = drawSellTransactions(
                in: context,
                sellTransactions: displayData.sellTransactions,
                pageRect: pageRect,
                currentY: currentY + PDFStylingImproved.sectionSpacing
            )
        }

        // Draw calculation breakdown
        currentY = drawCalculationBreakdown(
            in: context,
            calculationBreakdown: displayData.calculationBreakdown,
            pageRect: pageRect,
            currentY: currentY + PDFStylingImproved.sectionSpacing
        )

        // Draw tax summary
        currentY = drawTaxSummary(
            in: context,
            taxSummary: displayData.taxSummary,
            pageRect: pageRect,
            currentY: currentY + 20
        )

        // Draw footer
        drawFooter(
            in: context,
            displayData: displayData,
            pageRect: pageRect,
            currentY: currentY + 20
        )
    }

    // MARK: - Header Drawing

    private func drawHeader(
        in context: CGContext,
        trade: TradeOverviewItem,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        // Company name
        let companyText = PDFCompanyInfo.companyName
        let companyAttributes = PDFTextAttributesImproved.titleAttributes()
        companyText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: companyAttributes)
        y += PDFStylingImproved.titleFont.lineHeight + 12

        // Company details
        let companyDetailsAttributes = PDFTextAttributesImproved.secondaryBodyAttributes()
        for detail in PDFCompanyInfo.companyDetails {
            detail.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: companyDetailsAttributes)
            y += PDFStylingImproved.bodyFont.lineHeight + 3
        }

        y += PDFStylingImproved.sectionSpacing

        // Document title
        let titleText = "Collection Bill"
        let titleAttributes = PDFTextAttributesImproved.headerAttributes()
        titleText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: titleAttributes)
        y += PDFStylingImproved.headerFont.lineHeight + 8

        // Trade number
        let tradeNumberText = "Trade #\(String(format: "%03d", trade.tradeNumber))"
        let tradeNumberAttributes = PDFTextAttributesImproved.bodyAttributes()
        tradeNumberText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: tradeNumberAttributes)

        // Date on the right
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale(identifier: "de_DE")
        let dateText = "Datum: \(dateFormatter.string(from: Date()))"
        let dateSize = dateText.size(withAttributes: tradeNumberAttributes)
        dateText.draw(at: CGPoint(x: pageRect.width - PDFStylingImproved.margin - dateSize.width, y: y), withAttributes: tradeNumberAttributes)

        y += PDFStylingImproved.bodyFont.lineHeight + 8

        return y
    }

    // MARK: - Depot Info Drawing

    private func drawDepotInfo(
        in context: CGContext,
        displayData: TradeStatementDisplayData,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        let headerText = "Depot-Informationen"
        let headerAttributes = PDFTextAttributesImproved.subheaderAttributes()
        headerText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: headerAttributes)
        y += PDFStylingImproved.subheaderFont.lineHeight + 12

        let bodyAttributes = PDFTextAttributesImproved.bodyAttributes()
        let depotInfo = [
            "Depotnummer: \(displayData.depotNumber)",
            "Depotinhaber: \(displayData.depotHolder)",
            "Wertpapier: \(displayData.securityIdentifier)",
            "Kontonummer: \(displayData.accountNumber)"
        ]

        for info in depotInfo {
            info.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: bodyAttributes)
            y += PDFStylingImproved.bodyFont.lineHeight + 4
        }

        return y
    }

    // MARK: - Buy Transaction Drawing

    private func drawBuyTransaction(
        in context: CGContext,
        buyTransaction: BuyTransactionData,
        displayData: TradeStatementDisplayData,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        let headerText = "Kauf-Transaktion"
        let headerAttributes = PDFTextAttributesImproved.subheaderAttributes()
        headerText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: headerAttributes)
        y += PDFStylingImproved.subheaderFont.lineHeight + 12

        // Create table for buy transaction
        let tableData = [
            ["Transaktionsnummer", buyTransaction.transactionNumber],
            ["Volumen", buyTransaction.orderVolume],
            ["Ausgeführtes Volumen", buyTransaction.executedVolume],
            ["Preis", buyTransaction.price],
            ["Marktwert", buyTransaction.marketValue],
            ["Provision", buyTransaction.commission],
            ["Eigene Kosten", buyTransaction.ownExpenses],
            ["Externe Kosten", buyTransaction.externalExpenses],
            ["Endbetrag", buyTransaction.finalAmount]
        ]

        y = drawInfoTable(
            in: context,
            data: tableData,
            pageRect: pageRect,
            currentY: y
        )

        return y
    }

    // MARK: - Sell Transactions Drawing

    private func drawSellTransactions(
        in context: CGContext,
        sellTransactions: [SellTransactionData],
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        let headerText = "Verkauf-Transaktionen"
        let headerAttributes = PDFTextAttributesImproved.subheaderAttributes()
        headerText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: headerAttributes)
        y += PDFStylingImproved.subheaderFont.lineHeight + 12

        // Create table for sell transactions
        let contentWidth = PDFStylingImproved.contentWidth
        let columnWidths = PDFStylingImproved.sellTableColumnWidthRatios.map { contentWidth * $0 }

        // Table header
        let headerRect = CGRect(
            x: PDFStylingImproved.margin,
            y: y,
            width: contentWidth,
            height: PDFStylingImproved.tableHeaderHeight
        )

        context.setFillColor(PDFStylingImproved.tableHeaderBackgroundColor.cgColor)
        context.fill(headerRect)

        let headerTitles = ["Transaktionsnummer", "Volumen", "Preis", "Marktwert", "Provision", "Endbetrag"]
        let tableHeaderAttributes = PDFTextAttributesImproved.tableHeaderAttributes()
        var x = PDFStylingImproved.margin

        for (index, title) in headerTitles.enumerated() {
            let textRect = CGRect(
                x: x + PDFStylingImproved.tableCellPadding,
                y: y + (PDFStylingImproved.tableHeaderHeight - PDFStylingImproved.tableHeaderFont.lineHeight) / 2,
                width: columnWidths[index] - (PDFStylingImproved.tableCellPadding * 2),
                height: PDFStylingImproved.tableHeaderFont.lineHeight
            )

            let attributedTitle = NSMutableAttributedString(string: title, attributes: tableHeaderAttributes)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = index == 0 ? .left : .right
            attributedTitle.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: title.count))

            attributedTitle.draw(in: textRect)
            x += columnWidths[index]
        }

        y += PDFStylingImproved.tableHeaderHeight

        // Table rows
        let rowAttributes = PDFTextAttributesImproved.tableCellAttributes()

        for (index, transaction) in sellTransactions.enumerated() {
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

            context.setStrokeColor(PDFStylingImproved.separatorColor.cgColor)
            context.setLineWidth(PDFStylingImproved.tableBorderWidth)
            context.stroke(rowRect)

            x = PDFStylingImproved.margin
            let rowData = [
                transaction.transactionNumber,
                transaction.orderVolume,
                transaction.price,
                transaction.marketValue,
                transaction.commission,
                transaction.finalAmount
            ]

            for (colIndex, data) in rowData.enumerated() {
                let alignment: NSTextAlignment = colIndex == 0 ? .left : .right
                let cellRect = CGRect(
                    x: x + PDFStylingImproved.tableCellPadding,
                    y: y + (PDFStylingImproved.tableRowHeight - PDFStylingImproved.tableFont.lineHeight) / 2,
                    width: columnWidths[colIndex] - (PDFStylingImproved.tableCellPadding * 2),
                    height: PDFStylingImproved.tableFont.lineHeight
                )

                let attributedData = NSMutableAttributedString(string: data, attributes: rowAttributes)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = alignment
                attributedData.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: data.count))

                attributedData.draw(in: cellRect)
                x += columnWidths[colIndex]
            }

            y += PDFStylingImproved.tableRowHeight
        }

        // Bottom border
        context.setStrokeColor(PDFStylingImproved.separatorColor.cgColor)
        context.setLineWidth(PDFStylingImproved.tableBorderWidth * 2)
        context.move(to: CGPoint(x: PDFStylingImproved.margin, y: y))
        context.addLine(to: CGPoint(x: PDFStylingImproved.margin + contentWidth, y: y))
        context.strokePath()

        return y
    }

    // MARK: - Calculation Breakdown Drawing

    private func drawCalculationBreakdown(
        in context: CGContext,
        calculationBreakdown: CalculationBreakdownData,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        let headerText = "Berechnungsübersicht"
        let headerAttributes = PDFTextAttributesImproved.subheaderAttributes()
        headerText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: headerAttributes)
        y += PDFStylingImproved.subheaderFont.lineHeight + 12

        let tableData = [
            ["Gesamt-Verkaufsbetrag", calculationBreakdown.totalSellAmount],
            ["Kaufbetrag", calculationBreakdown.buyAmount],
            ["Ergebnis vor Steuern", calculationBreakdown.resultBeforeTaxes]
        ]

        y = drawInfoTable(
            in: context,
            data: tableData,
            pageRect: pageRect,
            currentY: y
        )

        return y
    }

    // MARK: - Tax Summary Drawing

    private func drawTaxSummary(
        in context: CGContext,
        taxSummary: TaxSummaryData,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY + 15

        let headerText = "Steuerübersicht"
        let headerAttributes = PDFTextAttributesImproved.subheaderAttributes()
        headerText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: headerAttributes)
        y += PDFStylingImproved.subheaderFont.lineHeight + 12

        let totalsX = pageRect.width - PDFStylingImproved.margin - PDFStylingImproved.totalsWidth
        let totalsAttributes = PDFTextAttributesImproved.totalsAttributes()

        // Assessment basis
        let assessmentText = "Bemessungsgrundlage:"
        let assessmentValue = taxSummary.assessmentBasis
        let assessmentSize = assessmentText.size(withAttributes: totalsAttributes)
        assessmentText.draw(at: CGPoint(x: totalsX, y: y), withAttributes: totalsAttributes)
        assessmentValue.draw(at: CGPoint(x: totalsX + assessmentSize.width + 10, y: y), withAttributes: totalsAttributes)
        y += 22

        // Total tax
        let taxText = "Gesamtsteuer:"
        let taxValue = taxSummary.totalTax
        let taxSize = taxText.size(withAttributes: totalsAttributes)
        taxText.draw(at: CGPoint(x: totalsX, y: y), withAttributes: totalsAttributes)
        taxValue.draw(at: CGPoint(x: totalsX + taxSize.width + 10, y: y), withAttributes: totalsAttributes)
        y += 22

        // Net result (highlighted)
        let netText = "Nettoergebnis:"
        let netValue = taxSummary.netResult
        let netTextSize = netText.size(withAttributes: totalsAttributes)
        netText.draw(at: CGPoint(x: totalsX, y: y), withAttributes: totalsAttributes)

        var netValueAttributes = totalsAttributes
        netValueAttributes[.font] = PDFStylingImproved.headerFont
        netValueAttributes[.foregroundColor] = PDFStylingImproved.primaryColor
        netValue.draw(at: CGPoint(x: totalsX + netTextSize.width + 10, y: y), withAttributes: netValueAttributes)

        // Underline
        y += 20
        context.setStrokeColor(PDFStylingImproved.primaryColor.cgColor)
        context.setLineWidth(1.5)
        let underlineX = totalsX + netTextSize.width + 10
        let underlineWidth = netValue.size(withAttributes: netValueAttributes).width
        context.move(to: CGPoint(x: underlineX, y: y))
        context.addLine(to: CGPoint(x: underlineX + underlineWidth, y: y))
        context.strokePath()

        return y
    }

    // MARK: - Footer Drawing

    private func drawFooter(
        in context: CGContext,
        displayData: TradeStatementDisplayData,
        pageRect: CGRect,
        currentY: CGFloat
    ) {
        var y = currentY + 20

        // Separator
        context.setStrokeColor(PDFStylingImproved.separatorColor.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: PDFStylingImproved.margin, y: y))
        context.addLine(to: CGPoint(x: pageRect.width - PDFStylingImproved.margin, y: y))
        context.strokePath()
        y += 20

        // Legal disclaimer
        let disclaimerAttributes = PDFTextAttributesImproved.smallAttributes()
        let disclaimerRect = CGRect(
            x: PDFStylingImproved.margin,
            y: y,
            width: PDFStylingImproved.contentWidth,
            height: 200
        )
        displayData.legalDisclaimer.draw(in: disclaimerRect, withAttributes: disclaimerAttributes)
        y += 210

        // Additional legal info
        let additionalInfoAttributes = PDFTextAttributesImproved.smallAttributes()
        for info in PDFCompanyInfo.additionalLegalInfo {
            info.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: additionalInfoAttributes)
            y += PDFStylingImproved.smallFont.lineHeight + 3
        }
    }

    // MARK: - Helper Methods

    private func drawInfoTable(
        in context: CGContext,
        data: [[String]],
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY
        let contentWidth = PDFStylingImproved.contentWidth
        let labelWidth = contentWidth * PDFStylingImproved.infoTableLabelWidthRatio
        let valueWidth = contentWidth * PDFStylingImproved.infoTableValueWidthRatio

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
            let labelRect = CGRect(
                x: PDFStylingImproved.margin + PDFStylingImproved.tableCellPadding,
                y: y + (PDFStylingImproved.tableRowHeight - PDFStylingImproved.bodyFont.lineHeight) / 2,
                width: labelWidth - (PDFStylingImproved.tableCellPadding * 2),
                height: PDFStylingImproved.bodyFont.lineHeight
            )
            label.draw(in: labelRect, withAttributes: bodyAttributes)

            // Value (right-aligned)
            let value = row[1]
            var valueAttributes = bodyAttributes
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right
            valueAttributes[.paragraphStyle] = paragraphStyle

            let valueRect = CGRect(
                x: PDFStylingImproved.margin + labelWidth + PDFStylingImproved.tableCellPadding,
                y: y + (PDFStylingImproved.tableRowHeight - PDFStylingImproved.bodyFont.lineHeight) / 2,
                width: valueWidth - (PDFStylingImproved.tableCellPadding * 2),
                height: PDFStylingImproved.bodyFont.lineHeight
            )
            value.draw(in: valueRect, withAttributes: valueAttributes)

            y += PDFStylingImproved.tableRowHeight
        }

        return y
    }
}
