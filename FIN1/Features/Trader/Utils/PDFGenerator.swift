import Foundation
import UIKit
import PDFKit
import OSLog

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
    static var generationMode: PDFGenerationMode = .backend

    /// Toggle to use improved local PDF generation (default: true)
    /// Only applies when generationMode is .local
    static var useImprovedGeneration: Bool = true

    /// Backend service instance (lazy initialized)
    private static var _backendService: PDFBackendService?
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
        logger.info("PDFGenerator.generatePDF - Mode: \(generationMode.rawValue)")

        switch generationMode {
        case .backend:
            // For synchronous API compatibility, fall back to local generation
            // Use generatePDFAsync for backend generation
            logger.info("Falling back to local generation for sync call")
            return generateLocalPDF(from: invoice)

        case .professionalLocal:
            return PDFInvoiceGenerator.generatePDF(from: invoice)

        case .local:
            return generateLocalPDF(from: invoice)
        }
    }

    /// Generates a PDF from an invoice asynchronously (supports backend generation)
    static func generatePDFAsync(from invoice: Invoice) async throws -> Data {
        logger.info("PDFGenerator.generatePDFAsync - Mode: \(generationMode.rawValue)")

        switch generationMode {
        case .backend:
            do {
                let data = try await backendService.generateInvoicePDF(from: invoice)
                logger.info("Backend PDF generated: \(data.count) bytes")
                return data
            } catch {
                logger.error("Backend PDF generation failed, falling back to local: \(error.localizedDescription)")
                return generateLocalPDF(from: invoice)
            }

        case .professionalLocal:
            return PDFInvoiceGenerator.generatePDF(from: invoice)

        case .local:
            return generateLocalPDF(from: invoice)
        }
    }

    /// Generates a trade statement PDF asynchronously
    static func generateTradeStatementPDFAsync(
        for displayData: TradeStatementDisplayData,
        trade: TradeOverviewItem
    ) async throws -> Data {
        logger.info("Generating trade statement PDF - Mode: \(generationMode.rawValue)")

        switch generationMode {
        case .backend:
            do {
                return try await backendService.generateTradeStatementPDF(for: displayData, trade: trade)
            } catch {
                logger.error("Backend trade statement PDF failed, falling back to local: \(error.localizedDescription)")
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
        logger.info("Generating credit note PDF - Mode: \(generationMode.rawValue)")

        switch generationMode {
        case .backend:
            do {
                return try await backendService.generateCreditNotePDF(from: invoice)
            } catch {
                logger.error("Backend credit note PDF failed, falling back to local: \(error.localizedDescription)")
                return PDFInvoiceGenerator.generatePDF(from: invoice)
            }

        case .professionalLocal, .local:
            return PDFInvoiceGenerator.generatePDF(from: invoice)
        }
    }

    /// Generates a preview image of the PDF
    static func generatePreview(from invoice: Invoice) -> UIImage? {
        switch generationMode {
        case .professionalLocal:
            return PDFInvoiceGenerator.generatePreview(from: invoice)

        case .backend, .local:
            if useImprovedGeneration {
                return PDFCoreGeneratorImproved.generatePreview(from: invoice)
            } else {
                return PDFCoreGenerator.generatePreview(from: invoice)
            }
        }
    }

    // MARK: - Private Methods

    private static func generateLocalPDF(from invoice: Invoice) -> Data {
        let pdfData: Data
        if useImprovedGeneration {
            pdfData = PDFCoreGeneratorImproved.generatePDF(from: invoice)
        } else {
            pdfData = PDFCoreGenerator.generatePDF(from: invoice)
        }

        logger.info("Local PDF generated: \(pdfData.count) bytes")
        return pdfData
    }
}
