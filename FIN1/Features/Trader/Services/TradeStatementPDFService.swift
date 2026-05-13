import Foundation
import SwiftUI

// MARK: - PDF Service Protocol

/// Protocol for generating PDF documents for trade statements
protocol TradeStatementPDFServiceProtocol {
    /// Generates a PDF for the given trade statement data
    func generatePDF(for displayData: TradeStatementDisplayData, trade: TradeOverviewItem) async throws -> Data

    /// Generates a PDF preview image for the given trade statement data
    func generatePreview(for displayData: TradeStatementDisplayData, trade: TradeOverviewItem) async throws -> UIImage

    /// Saves PDF data to the Documents folder
    func savePDFToDocuments(_ pdfData: Data, fileName: String) async throws -> URL
}

// MARK: - PDF Service Implementation

/// Service responsible for generating PDF documents for trade statements
final class TradeStatementPDFService: TradeStatementPDFServiceProtocol {

    // MARK: - Configuration

    /// Toggle to use improved PDF generation (default: true)
    /// Set to false to use legacy PDF generation
    nonisolated(unsafe) static var useImprovedGeneration: Bool = true

    // MARK: - Public Methods

    func generatePDF(for displayData: TradeStatementDisplayData, trade: TradeOverviewItem) async throws -> Data {
        if Self.useImprovedGeneration {
            return try await TradeStatementPDFServiceImproved().generatePDF(for: displayData, trade: trade)
        }

        // Legacy implementation
        print("🔧 TradeStatementPDFService: Starting PDF generation for Trade #\(trade.tradeNumber)")

        let pdfContent = self.createPDFContent(from: displayData, trade: trade)
        let pdfData = try await createPDFData(from: pdfContent)

        print("🔧 TradeStatementPDFService: PDF generated successfully, size: \(pdfData.count) bytes")
        return pdfData
    }

    func generatePreview(for displayData: TradeStatementDisplayData, trade: TradeOverviewItem) async throws -> UIImage {
        if Self.useImprovedGeneration {
            return try await TradeStatementPDFServiceImproved().generatePreview(for: displayData, trade: trade)
        }

        // Legacy implementation
        print("🔧 TradeStatementPDFService: Generating PDF preview for Trade #\(trade.tradeNumber)")

        let pdfData = try await generatePDF(for: displayData, trade: trade)

        // Convert PDF to image for preview
        guard let image = await convertPDFToImage(pdfData) else {
            throw PDFGenerationError.previewConversionFailed
        }

        print("🔧 TradeStatementPDFService: PDF preview generated successfully")
        return image
    }

    func savePDFToDocuments(_ pdfData: Data, fileName: String) async throws -> URL {
        if Self.useImprovedGeneration {
            return try await TradeStatementPDFServiceImproved().savePDFToDocuments(pdfData, fileName: fileName)
        }

        // Legacy implementation
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(fileName).pdf")

        try pdfData.write(to: fileURL)
        print("🔧 TradeStatementPDFService: PDF saved to \(fileURL.path)")
        return fileURL
    }

    // MARK: - Private Methods

    private func createPDFContent(from displayData: TradeStatementDisplayData, trade: TradeOverviewItem) -> String {
        var content = """
        COLLECTION BILL - Trade #\(String(format: "%03d", trade.tradeNumber))
        
        Depot Number: \(displayData.depotNumber)
        Depot Holder: \(displayData.depotHolder)
        
        """

        if let buyTransaction = displayData.buyTransaction {
            content += """
            BUY TRANSACTION:
            Security: \(displayData.securityIdentifier)
            Volume: \(buyTransaction.orderVolume)
            Price: \(buyTransaction.price)
            Market Value: \(buyTransaction.marketValue)
            Commission: \(buyTransaction.commission)
            Final Amount: \(buyTransaction.finalAmount)
            
            """
        }

        if !displayData.sellTransactions.isEmpty {
            content += """
            SELL TRANSACTION(S):
            """
            for (index, sellTransaction) in displayData.sellTransactions.enumerated() {
                content += """
                Transaction \(index + 1):
                Volume: \(sellTransaction.orderVolume)
                Price: \(sellTransaction.price)
                Market Value: \(sellTransaction.marketValue)
                Commission: \(sellTransaction.commission)
                Final Amount: \(sellTransaction.finalAmount)
                
                """
            }
        }

        content += """
        TAX SUMMARY:
        Assessment Basis: \(displayData.taxSummary.assessmentBasis)
        Total Tax: \(displayData.taxSummary.totalTax)
        Net Result: \(displayData.taxSummary.netResult)
        
        \(displayData.legalDisclaimer)
        """

        return content
    }

    private func createPDFData(from content: String) async throws -> Data {
        // Simple PDF creation - in a real app, you'd use a proper PDF library like PDFKit
        let pdfString = self.generatePDFTemplate(with: content)

        guard let data = pdfString.data(using: .utf8) else {
            throw PDFGenerationError.dataConversionFailed
        }

        return data
    }

    private func generatePDFTemplate(with content: String) -> String {
        let contentLength = content.utf8.count
        let xrefOffset = contentLength + 300

        return """
        %PDF-1.4
        \(self.generatePDFCatalog())
        \(self.generatePDFPages())
        \(self.generatePDFPage(contentLength: contentLength))
        \(self.generatePDFContent(content: content, contentLength: contentLength))
        \(self.generatePDFXref())
        \(self.generatePDFTrailer())
        startxref
        \(xrefOffset)
        %%EOF
        """
    }

    private func generatePDFCatalog() -> String {
        return """
        1 0 obj
        <<
        /Type /Catalog
        /Pages 2 0 R
        >>
        endobj
        """
    }

    private func generatePDFPages() -> String {
        return """
        2 0 obj
        <<
        /Type /Pages
        /Kids [3 0 R]
        /Count 1
        >>
        endobj
        """
    }

    private func generatePDFPage(contentLength: Int) -> String {
        return """
        3 0 obj
        <<
        /Type /Page
        /Parent 2 0 R
        /MediaBox [0 0 612 792]
        /Contents 4 0 R
        >>
        endobj
        """
    }

    private func generatePDFContent(content: String, contentLength: Int) -> String {
        return """
        4 0 obj
        <<
        /Length \(contentLength)
        >>
        stream
        BT
        /F1 12 Tf
        50 750 Td
        (\(content)) Tj
        ET
        endstream
        endobj
        """
    }

    private func generatePDFXref() -> String {
        return """
        xref
        0 5
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000204 00000 n
        """
    }

    private func generatePDFTrailer() -> String {
        return """
        trailer
        <<
        /Size 5
        /Root 1 0 R
        >>
        """
    }

    private func convertPDFToImage(_ pdfData: Data) async -> UIImage? {
        // Simple implementation - in a real app, you'd use a proper PDF to image conversion
        // For now, return a placeholder image
        let size = CGSize(width: 200, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.lightGray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }
}

// MARK: - PDF Generation Errors

enum PDFGenerationError: LocalizedError {
    case dataConversionFailed
    case previewConversionFailed
    case fileSaveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .dataConversionFailed:
            return "Failed to convert PDF content to data"
        case .previewConversionFailed:
            return "Failed to convert PDF to preview image"
        case .fileSaveFailed(let error):
            return "Failed to save PDF file: \(error.localizedDescription)"
        }
    }
}
