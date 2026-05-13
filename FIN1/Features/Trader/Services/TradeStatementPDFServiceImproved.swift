import Foundation
import OSLog
import PDFKit
import UIKit

// MARK: - Improved Trade Statement PDF Service
/// Professional PDF generator for trade statements (Collection Bills) with improved styling

final class TradeStatementPDFServiceImproved: TradeStatementPDFServiceProtocol {

    // MARK: - Logger
    private let logger = Logger(subsystem: "com.fin1.app", category: "TradeStatementPDFService")

    // MARK: - Public Methods

    func generatePDF(for displayData: TradeStatementDisplayData, trade: TradeOverviewItem) async throws -> Data {
        self.logger.info("Starting PDF generation for Trade #\(trade.tradeNumber)")

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

            self.drawCollectionBill(in: cgContext, displayData: displayData, trade: trade, pageRect: pageRect)
        }

        self.logger.info("PDF generated successfully, size: \(pdfData.count) bytes")
        return pdfData
    }

    func generatePreview(for displayData: TradeStatementDisplayData, trade: TradeOverviewItem) async throws -> UIImage {
        self.logger.info("Generating PDF preview for Trade #\(trade.tradeNumber)")

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

        self.logger.info("PDF preview generated successfully")
        return image
    }

    func savePDFToDocuments(_ pdfData: Data, fileName: String) async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(fileName).pdf")

        try pdfData.write(to: fileURL)
        self.logger.info("PDF saved to \(fileURL.path)")
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
}
