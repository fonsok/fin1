import Foundation
import UIKit

// MARK: - Invoice PDF / Export Service Protocol
/// Contract for invoice PDF generation and export (save to documents).
/// Keeps PDF/export logic separate from core invoice CRUD.
protocol InvoicePDFServiceProtocol {
    func generatePDF(for invoice: Invoice) async throws -> Data
    func generatePDFPreview(for invoice: Invoice) async throws -> UIImage
    func savePDFToDocuments(_ pdfData: Data, fileName: String) async throws -> URL
}
