import Foundation
import UIKit
import PDFKit

// MARK: - Professional Trade Statement PDF Generator
/// Generates DIN A4 compliant trade statements (Collection Bills) following German business standards

struct PDFTradeStatementGenerator {

    // MARK: - PDF Generation

    /// Generates a professional PDF trade statement
    /// - Parameters:
    ///   - displayData: The trade statement display data
    ///   - trade: The trade overview item
    /// - Returns: PDF data
    static func generatePDF(
        for displayData: TradeStatementDisplayData,
        trade: TradeOverviewItem
    ) -> Data {
        let pdfMetaData = createMetadata(for: trade)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData

        let renderer = UIGraphicsPDFRenderer(bounds: PDFDocumentLayout.pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            let cgContext = context.cgContext
            configureRenderingQuality(cgContext)

            drawTradeStatement(
                in: cgContext,
                displayData: displayData,
                trade: trade,
                pageRect: PDFDocumentLayout.pageRect
            )
        }

        return data
    }

    /// Generates a preview image of the trade statement
    static func generatePreview(
        for displayData: TradeStatementDisplayData,
        trade: TradeOverviewItem
    ) -> UIImage? {
        let pdfData = generatePDF(for: displayData, trade: trade)

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

    private static func drawTradeStatement(
        in context: CGContext,
        displayData: TradeStatementDisplayData,
        trade: TradeOverviewItem,
        pageRect: CGRect
    ) {
        var currentY: CGFloat = PDFDocumentLayout.topMargin

        // 1. Header with company info
        currentY = PDFProfessionalComponents.drawHeader(
            in: context,
            pageRect: pageRect,
            qrCodeImage: nil  // No QR code for trade statements
        )

        // 2. Address block and Info block
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale(identifier: "de_DE")

        let infoFields = PDFInfoBlockConfig.tradeStatementFields(
            tradeNumber: String(format: "%03d", trade.tradeNumber),
            date: dateFormatter.string(from: Date()),
            depotNumber: displayData.depotNumber,
            accountNumber: displayData.accountNumber
        )

        currentY = PDFProfessionalComponents.drawAddressAndInfoBlock(
            in: context,
            pageRect: pageRect,
            recipientName: displayData.depotHolder,
            recipientAddress: "",  // Address handled elsewhere for trade statements
            recipientCity: "",
            infoFields: infoFields,
            currentY: currentY
        )

        // 3. Document title
        currentY = PDFProfessionalComponents.drawDocumentTitle(
            in: context,
            pageRect: pageRect,
            title: "Sammelabrechnung",
            subtitle: "Trade #\(String(format: "%03d", trade.tradeNumber)) - \(displayData.securityIdentifier)",
            currentY: currentY
        )

        // 4. Depot information section
        currentY = drawDepotInfo(
            in: context,
            displayData: displayData,
            pageRect: pageRect,
            currentY: currentY
        )

        // 5. Buy transaction (if exists)
        if let buyTransaction = displayData.buyTransaction {
            currentY = drawBuyTransaction(
                in: context,
                buyTransaction: buyTransaction,
                pageRect: pageRect,
                currentY: currentY
            )
        }

        // 6. Sell transactions (if exist)
        if !displayData.sellTransactions.isEmpty {
            currentY = drawSellTransactions(
                in: context,
                sellTransactions: displayData.sellTransactions,
                pageRect: pageRect,
                currentY: currentY
            )
        }

        // 7. Calculation breakdown
        currentY = drawCalculationBreakdown(
            in: context,
            calculationBreakdown: displayData.calculationBreakdown,
            pageRect: pageRect,
            currentY: currentY
        )

        // 8. Tax summary with net result
        currentY = drawTaxSummary(
            in: context,
            taxSummary: displayData.taxSummary,
            pageRect: pageRect,
            currentY: currentY
        )

        // 9. Footer with legal disclaimer
        PDFProfessionalComponents.drawFooter(
            in: context,
            pageRect: pageRect,
            notes: [displayData.legalDisclaimer],
            currentY: currentY
        )
    }

    // MARK: - Section Drawing

    private static func drawDepotInfo(
        in context: CGContext,
        displayData: TradeStatementDisplayData,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        y = PDFProfessionalComponents.drawSectionHeader(
            in: context,
            pageRect: pageRect,
            title: "Depot-Informationen",
            currentY: y
        )

        let depotInfo: [(label: String, value: String)] = [
            ("Depotnummer:", displayData.depotNumber),
            ("Depotinhaber:", displayData.depotHolder),
            ("Wertpapier:", displayData.securityIdentifier),
            ("Kontonummer:", displayData.accountNumber)
        ]

        y = PDFProfessionalComponents.drawInfoTable(
            in: context,
            pageRect: pageRect,
            data: depotInfo,
            currentY: y,
            labelWidthRatio: 0.35
        )

        return y + PDFDocumentLayout.sectionSpacing
    }

    private static func drawBuyTransaction(
        in context: CGContext,
        buyTransaction: BuyTransactionData,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        y = PDFProfessionalComponents.drawSectionHeader(
            in: context,
            pageRect: pageRect,
            title: "Kauf-Transaktion",
            currentY: y
        )

        let buyData: [(label: String, value: String)] = [
            ("Transaktionsnummer:", buyTransaction.transactionNumber),
            ("Ordervolumen:", buyTransaction.orderVolume),
            ("Ausgeführtes Volumen:", buyTransaction.executedVolume),
            ("Preis:", buyTransaction.price),
            ("Marktwert:", buyTransaction.marketValue),
            ("Provision:", buyTransaction.commission),
            ("Eigene Kosten:", buyTransaction.ownExpenses),
            ("Externe Kosten:", buyTransaction.externalExpenses),
            ("Endbetrag:", buyTransaction.finalAmount)
        ]

        y = PDFProfessionalComponents.drawInfoTable(
            in: context,
            pageRect: pageRect,
            data: buyData,
            currentY: y,
            labelWidthRatio: 0.45
        )

        return y + PDFDocumentLayout.sectionSpacing
    }

    private static func drawSellTransactions(
        in context: CGContext,
        sellTransactions: [SellTransactionData],
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        y = PDFProfessionalComponents.drawSectionHeader(
            in: context,
            pageRect: pageRect,
            title: "Verkauf-Transaktionen",
            currentY: y
        )

        // Column configuration for sell transactions
        let columnTitles = PDFTradeStatementTableConfig.sellTransactionColumns.map(\.title)
        let columnWidths = PDFTradeStatementTableConfig.sellColumnWidths(for: PDFDocumentLayout.contentWidth)
        let columnAlignments = PDFTradeStatementTableConfig.sellTransactionColumns.map(\.alignment)

        // Prepare row data
        let rows = sellTransactions.map { transaction in
            [
                transaction.transactionNumber,
                transaction.orderVolume,
                transaction.price,
                transaction.marketValue,
                transaction.commission,
                transaction.finalAmount
            ]
        }

        y = PDFProfessionalComponents.drawTable(
            in: context,
            pageRect: pageRect,
            columnTitles: columnTitles,
            columnWidths: columnWidths,
            columnAlignments: columnAlignments,
            rows: rows,
            currentY: y
        )

        return y + PDFDocumentLayout.sectionSpacing
    }

    private static func drawCalculationBreakdown(
        in context: CGContext,
        calculationBreakdown: CalculationBreakdownData,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        y = PDFProfessionalComponents.drawSectionHeader(
            in: context,
            pageRect: pageRect,
            title: "Berechnungsübersicht",
            currentY: y
        )

        let breakdownData: [(label: String, value: String)] = [
            ("Gesamt-Verkaufsbetrag:", calculationBreakdown.totalSellAmount),
            ("Kaufbetrag:", calculationBreakdown.buyAmount),
            ("Ergebnis vor Steuern:", calculationBreakdown.resultBeforeTaxes)
        ]

        y = PDFProfessionalComponents.drawInfoTable(
            in: context,
            pageRect: pageRect,
            data: breakdownData,
            currentY: y,
            labelWidthRatio: 0.50
        )

        return y + PDFDocumentLayout.sectionSpacing
    }

    private static func drawTaxSummary(
        in context: CGContext,
        taxSummary: TaxSummaryData,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY

        y = PDFProfessionalComponents.drawSectionHeader(
            in: context,
            pageRect: pageRect,
            title: "Steuerübersicht",
            currentY: y
        )

        let totalsItems: [(label: String, value: String, isFinal: Bool)] = [
            ("Bemessungsgrundlage:", taxSummary.assessmentBasis, false),
            ("Gesamtsteuer:", taxSummary.totalTax, false),
            ("Nettoergebnis:", taxSummary.netResult, true)
        ]

        y = PDFProfessionalComponents.drawTotalsSection(
            in: context,
            pageRect: pageRect,
            items: totalsItems,
            currentY: y
        )

        return y
    }

    // MARK: - Helpers

    private static func createMetadata(for trade: TradeOverviewItem) -> [String: Any] {
        [
            kCGPDFContextCreator as String: "\(LegalIdentity.platformName) Trading App",
            kCGPDFContextAuthor as String: LegalIdentity.companyLegalName,
            kCGPDFContextTitle as String: "Sammelabrechnung Trade #\(String(format: "%03d", trade.tradeNumber))"
        ]
    }

    private static func configureRenderingQuality(_ context: CGContext) {
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        context.setShouldSmoothFonts(true)
        context.interpolationQuality = .high
    }
}
