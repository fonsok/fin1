import Foundation
import SwiftUI
import UIKit

// MARK: - PDF Download Service
/// Service for handling PDF downloads via browser and system sharing
final class PDFDownloadService {

    // MARK: - Public Methods

    /// Downloads PDF via browser by creating a data URL and opening it
    /// - Parameters:
    ///   - pdfData: The PDF data to download
    ///   - fileName: The name of the file (without extension)
    ///   - fileExtension: The file extension (default: "pdf")
    static func downloadPDFViaBrowser(_ pdfData: Data, fileName: String, fileExtension: String = "pdf") {
        print("🔧 DEBUG: Starting browser-based PDF download for: \(fileName).\(fileExtension)")
        print("🔧 DEBUG: PDF data size: \(pdfData.count) bytes")

        // For very large PDFs, use share sheet instead of data URL
        if pdfData.count > 1_000_000 { // 1MB limit for data URLs
            print("🔧 DEBUG: PDF too large for data URL (\(pdfData.count) bytes), using share sheet instead")
            self.downloadPDFViaShareSheet(pdfData, fileName: fileName, fileExtension: fileExtension)
            return
        }

        // Create data URL for the PDF
        let mimeType = "application/pdf"
        let base64String = pdfData.base64EncodedString()
        let dataURL = "data:\(mimeType);base64,\(base64String)"

        print("🔧 DEBUG: Data URL length: \(dataURL.count) characters")

        // Check if data URL is too long (some browsers have limits)
        if dataURL.count > 2_000_000 { // 2MB limit for data URLs
            print("🔧 DEBUG: Data URL too long (\(dataURL.count) chars), using share sheet instead")
            self.downloadPDFViaShareSheet(pdfData, fileName: fileName, fileExtension: fileExtension)
            return
        }

        guard let url = URL(string: dataURL) else {
            print("❌ DEBUG: Failed to create data URL for PDF")
            self.downloadPDFViaShareSheet(pdfData, fileName: fileName, fileExtension: fileExtension)
            return
        }

        // Open the PDF in Safari for download
        // Note: UIApplication is still needed for opening URLs - this is minimal UIKit usage for system services
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url) { success in
                    if success {
                        print("📱 PDF opened in browser successfully")
                    } else {
                        print("❌ Failed to open PDF in browser, falling back to share sheet")
                        self.downloadPDFViaShareSheet(pdfData, fileName: fileName, fileExtension: fileExtension)
                    }
                }
            } else {
                print("❌ Cannot open URL in browser, falling back to share sheet")
                self.downloadPDFViaShareSheet(pdfData, fileName: fileName, fileExtension: fileExtension)
            }
        }
    }

    /// Fallback method to download PDF via share sheet
    /// Note: This method is deprecated - use sharePDFButton() for SwiftUI ShareLink instead
    private static func downloadPDFViaShareSheet(_ pdfData: Data, fileName: String, fileExtension: String) {
        print("🔧 DEBUG: Using share sheet fallback for PDF download")
        // This method is kept for backward compatibility but should use ShareLink in SwiftUI views
        // The file is created and can be shared via ShareLink
        _ = createTemporaryPDFFile(pdfData: pdfData, fileName: fileName, fileExtension: fileExtension)
    }

    /// Creates a shareable PDF file URL for use with ShareLink
    /// - Parameters:
    ///   - pdfData: The PDF data to share
    ///   - fileName: The name of the file (without extension)
    ///   - fileExtension: The file extension (default: "pdf")
    /// - Returns: The URL of the temporary PDF file for sharing
    static func createShareablePDFURL(_ pdfData: Data, fileName: String, fileExtension: String = "pdf") -> URL {
        return createTemporaryPDFFile(pdfData: pdfData, fileName: fileName, fileExtension: fileExtension)
    }

    /// Creates a shareable PDF file URL in the app's documents directory
    /// - Parameters:
    ///   - pdfData: The PDF data to save
    ///   - fileName: The name of the file (without extension)
    ///   - fileExtension: The file extension (default: "pdf")
    /// - Returns: The URL where the PDF was saved
    /// - Throws: AppError if saving fails
    static func savePDFToDocuments(_ pdfData: Data, fileName: String, fileExtension: String = "pdf") async throws -> URL {
        do {
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw NSError(
                    domain: "PDFDownloadService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not access documents directory"]
                )
            }
            let fileURL = documentsURL.appendingPathComponent("\(fileName).\(fileExtension)")

            print("🔧 DEBUG: Saving PDF to documents: \(fileURL.path)")
            print("🔧 DEBUG: PDF data size: \(pdfData.count) bytes")

            try pdfData.write(to: fileURL)
            print("📁 PDF saved to documents: \(fileURL.path)")

            return fileURL
        } catch {
            print("❌ Failed to save PDF to documents: \(error.localizedDescription)")
            throw AppError.serviceError(.operationFailed)
        }
    }
}

// MARK: - SwiftUI Integration
extension PDFDownloadService {

    /// SwiftUI wrapper for sharing PDF
    /// - Parameters:
    ///   - pdfData: The PDF data to share
    ///   - fileName: The name of the file (without extension)
    ///   - fileExtension: The file extension (default: "pdf")
    /// - Returns: A SwiftUI view that can be used to trigger the share sheet
    @ViewBuilder
    static func sharePDFButton(pdfData: Data, fileName: String, fileExtension: String = "pdf") -> some View {
        ShareLink(
            item: self.createTemporaryPDFFile(pdfData: pdfData, fileName: fileName, fileExtension: fileExtension),
            subject: Text("Wertpapierabrechnung"),
            message: Text("Anbei finden Sie Ihre Wertpapierabrechnung.")
        ) {
            Label("PDF Teilen", systemImage: "square.and.arrow.up")
        }
    }

    /// Creates a temporary PDF file for sharing
    private static func createTemporaryPDFFile(pdfData: Data, fileName: String, fileExtension: String) -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent("\(fileName).\(fileExtension)")

        do {
            try pdfData.write(to: fileURL)
            return fileURL
        } catch {
            print("❌ Failed to create temporary PDF file: \(error.localizedDescription)")
            return tempDirectory.appendingPathComponent("error.pdf")
        }
    }
}
