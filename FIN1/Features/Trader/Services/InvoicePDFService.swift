import Foundation
import UIKit

// MARK: - Invoice PDF Service
/// Handles PDF generation and export for invoices (delegates to PDFGenerator and PDFDownloadService).
/// Separates PDF/export from core invoice CRUD in InvoiceService.
final class InvoicePDFService: InvoicePDFServiceProtocol {

    func generatePDF(for invoice: Invoice) async throws -> Data {
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let pdfData = PDFGenerator.generatePDF(from: invoice)

        if pdfData.isEmpty {
            throw AppError.serviceError(.operationFailed)
        }

        return pdfData
    }

    func generatePDFPreview(for invoice: Invoice) async throws -> UIImage {
        try await Task.sleep(nanoseconds: 500_000_000)

        guard let preview = PDFGenerator.generatePreview(from: invoice) else {
            throw AppError.invoiceGenerationFailed
        }

        return preview
    }

    func savePDFToDocuments(_ pdfData: Data, fileName: String) async throws -> URL {
        try await PDFDownloadService.savePDFToDocuments(pdfData, fileName: fileName, fileExtension: "pdf")
    }
}
