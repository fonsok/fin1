import Foundation
import OSLog
import PDFKit
import UIKit

// MARK: - PDF Generation Mode

/// Configuration for PDF generation source
enum PDFGenerationMode: String {
    /// Generate PDFs locally using Core Graphics (fast, offline capable)
    case local

    /// Generate PDFs via backend service (professional, DIN A4 compliant)
    case backend

    /// Use professional local generator (new DIN 5008 layout)
    case professionalLocal
}

// MARK: - PDF Generator
/// Utility class for generating professional PDF invoices
/// Supports both local and backend PDF generation
final class PDFGenerator {

    // MARK: - Logger

    private static let logger = Logger(subsystem: "com.fin1.app", category: "PDFGenerator")

    // MARK: - Configuration

    /// PDF generation mode (default: backend for production quality)
    /// Set to .local for offline capability or .professionalLocal for new local layouts
    nonisolated(unsafe) static var generationMode: PDFGenerationMode = .backend

    /// Toggle to use improved local PDF generation (default: true)
    /// Only applies when generationMode is .local
    nonisolated(unsafe) static var useImprovedGeneration: Bool = true

    /// Backend service instance (lazy initialized)
    private nonisolated(unsafe) static var _backendService: PDFBackendService?
    private static var backendService: PDFBackendService {
        if _backendService == nil {
            _backendService = PDFBackendService()
        }
        return _backendService!
    }

    // MARK: - PDF Generation

    /// Generates a PDF from an invoice
    /// Uses configured generation mode (backend or local)
    static func generatePDF(from invoice: Invoice) -> Data {
        self.logger.info("PDFGenerator.generatePDF - Mode: \(self.generationMode.rawValue)")

        switch self.generationMode {
        case .backend:
            // For synchronous API compatibility, fall back to local generation
            // Use generatePDFAsync for backend generation
            self.logger.info("Falling back to local generation for sync call")
            return self.generateLocalPDF(from: invoice)

        case .professionalLocal:
            return PDFInvoiceGenerator.generatePDF(from: invoice)

        case .local:
            return self.generateLocalPDF(from: invoice)
        }
    }

    /// Generates a PDF from an invoice asynchronously (supports backend generation)
    static func generatePDFAsync(from invoice: Invoice) async throws -> Data {
        self.logger.info("PDFGenerator.generatePDFAsync - Mode: \(self.generationMode.rawValue)")

        switch self.generationMode {
        case .backend:
            do {
                let data = try await backendService.generateInvoicePDF(from: invoice)
                self.logger.info("Backend PDF generated: \(data.count) bytes")
                return data
            } catch {
                self.logger.error("Backend PDF generation failed, falling back to local: \(error.localizedDescription)")
                return self.generateLocalPDF(from: invoice)
            }

        case .professionalLocal:
            return PDFInvoiceGenerator.generatePDF(from: invoice)

        case .local:
            return self.generateLocalPDF(from: invoice)
        }
    }

    /// Generates a trade statement PDF asynchronously
    static func generateTradeStatementPDFAsync(
        for displayData: TradeStatementDisplayData,
        trade: TradeOverviewItem
    ) async throws -> Data {
        self.logger.info("Generating trade statement PDF - Mode: \(self.generationMode.rawValue)")

        switch self.generationMode {
        case .backend:
            do {
                return try await self.backendService.generateTradeStatementPDF(for: displayData, tradeNumber: trade.tradeNumber)
            } catch {
                self.logger.error("Backend trade statement PDF failed, falling back to local: \(error.localizedDescription)")
                return PDFTradeStatementGenerator.generatePDF(for: displayData, trade: trade)
            }

        case .professionalLocal:
            return PDFTradeStatementGenerator.generatePDF(for: displayData, trade: trade)

        case .local:
            // Use the professional local generator (same as professionalLocal mode)
            return PDFTradeStatementGenerator.generatePDF(for: displayData, trade: trade)
        }
    }

    /// Generates a credit note PDF asynchronously
    static func generateCreditNotePDFAsync(from invoice: Invoice) async throws -> Data {
        self.logger.info("Generating credit note PDF - Mode: \(self.generationMode.rawValue)")

        switch self.generationMode {
        case .backend:
            do {
                return try await self.backendService.generateCreditNotePDF(from: invoice)
            } catch {
                self.logger.error("Backend credit note PDF failed, falling back to local: \(error.localizedDescription)")
                return PDFInvoiceGenerator.generatePDF(from: invoice)
            }

        case .professionalLocal, .local:
            return PDFInvoiceGenerator.generatePDF(from: invoice)
        }
    }

    /// Generates a preview image of the PDF
    static func generatePreview(from invoice: Invoice) -> UIImage? {
        switch self.generationMode {
        case .professionalLocal:
            return PDFInvoiceGenerator.generatePreview(from: invoice)

        case .backend, .local:
            if self.useImprovedGeneration {
                return PDFCoreGeneratorImproved.generatePreview(from: invoice)
            } else {
                return PDFCoreGenerator.generatePreview(from: invoice)
            }
        }
    }

    // MARK: - Private Methods

    private static func generateLocalPDF(from invoice: Invoice) -> Data {
        let pdfData: Data
        if self.useImprovedGeneration {
            pdfData = PDFCoreGeneratorImproved.generatePDF(from: invoice)
        } else {
            pdfData = PDFCoreGenerator.generatePDF(from: invoice)
        }

        self.logger.info("Local PDF generated: \(pdfData.count) bytes")
        return pdfData
    }
}
