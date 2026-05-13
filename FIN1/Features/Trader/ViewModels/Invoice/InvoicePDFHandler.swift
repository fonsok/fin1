import Foundation
import UIKit

// MARK: - Invoice PDF Handler

/// Handles PDF generation and download operations for InvoiceViewModel
/// Separated to reduce main ViewModel file size and improve maintainability
@MainActor
final class InvoicePDFHandler {
    private let invoiceService: any InvoiceServiceProtocol
    private let notificationService: any NotificationServiceProtocol

    init(
        invoiceService: any InvoiceServiceProtocol,
        notificationService: any NotificationServiceProtocol
    ) {
        self.invoiceService = invoiceService
        self.notificationService = notificationService
    }

    /// Generates a PDF for the selected invoice
    func generatePDF(
        for invoice: Invoice,
        progressCallback: @escaping (Double) -> Void,
        completionCallback: @escaping () -> Void,
        errorCallback: @escaping (Error) -> Void
    ) async {
        progressCallback(0.0)

        do {
            print("🔧 DEBUG: Starting PDF generation process for invoice: \(invoice.formattedInvoiceNumber)")

            // Simulate progress updates
            for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                progressCallback(progress)
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }

            print("🔧 DEBUG: Generating PDF data...")
            let pdfData = try await invoiceService.generatePDF(for: invoice)
            print("🔧 DEBUG: PDF data generated successfully, size: \(pdfData.count) bytes")

            // Save PDF to Documents folder for sharing
            let fileName = "\(invoice.formattedInvoiceNumber)_\(Date().timeIntervalSince1970)"
            print("🔧 DEBUG: Saving PDF with filename: \(fileName)")

            let fileURL = try await invoiceService.savePDFToDocuments(pdfData, fileName: fileName)
            print("🔧 DEBUG: PDF saved successfully to: \(fileURL.path)")

            progressCallback(1.0)
            completionCallback()

            // Show success message
            print("📁 PDF saved to Documents folder: \(fileURL.path)")

            // Create notification for user
            await self.createPDFSavedNotification(invoice: invoice, fileURL: fileURL)

        } catch {
            print("❌ DEBUG: PDF generation failed in Handler: \(error.localizedDescription)")
            print("❌ DEBUG: Error type: \(type(of: error))")
            print("❌ DEBUG: Error details: \(error)")

            progressCallback(0.0)
            errorCallback(error)
        }
    }

    /// Creates a shareable PDF URL for use with ShareLink
    /// - Parameter invoice: The invoice to generate PDF for
    /// - Returns: The URL of the PDF file ready for sharing, or nil if generation fails
    func createShareablePDFURL(for invoice: Invoice) async -> URL? {
        do {
            print("🔧 DEBUG: Starting PDF generation for sharing: \(invoice.formattedInvoiceNumber)")

            let pdfData = try await invoiceService.generatePDF(for: invoice)
            print("🔧 DEBUG: PDF data generated for sharing, size: \(pdfData.count) bytes")

            let fileName = "\(invoice.formattedInvoiceNumber)_\(Date().timeIntervalSince1970)"
            let fileURL = PDFDownloadService.createShareablePDFURL(pdfData, fileName: fileName)

            return fileURL
        } catch {
            print("❌ DEBUG: PDF generation failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Downloads PDF via browser
    func downloadPDFViaBrowser(for invoice: Invoice) async throws {
        print("🔧 DEBUG: Starting browser PDF download for invoice: \(invoice.formattedInvoiceNumber)")

        let pdfData = try await invoiceService.generatePDF(for: invoice)
        print("🔧 DEBUG: PDF data generated for browser download, size: \(pdfData.count) bytes")

        let fileName = "\(invoice.formattedInvoiceNumber)_\(Date().timeIntervalSince1970)"
        PDFDownloadService.downloadPDFViaBrowser(pdfData, fileName: fileName)
    }

    /// Generates a PDF preview for the selected invoice
    func generatePDFPreview(for invoice: Invoice) async throws -> UIImage {
        try await self.invoiceService.generatePDFPreview(for: invoice)
    }

    private func createPDFSavedNotification(invoice: Invoice, fileURL: URL) async {
        let title = "PDF Invoice Generated"
        let message = "Invoice \(invoice.formattedInvoiceNumber) has been saved to your Downloads folder."

        self.notificationService.createNotification(
            title: title,
            message: message,
            type: .document,
            priority: .medium,
            for: "current_user", // In a real app, this would be the actual user ID
            metadata: nil
        )

        print("📱 Created notification: \(title) - \(message)")
    }
}







