import SwiftUI
import UIKit

struct InvestorCollectionBillDocumentView: View {
    let document: Document
    let previewImage: UIImage
    let pdfData: Data?

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(20)) {
                PDFPreviewSection

                documentDetailsSection

                actionButtons
            }
            .padding(ResponsiveDesign.spacing(16))
        }
        .background(AppTheme.systemSecondaryBackground)
    }

    private var PDFPreviewSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Preview")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            PDFPreviewView(image: previewImage)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12)))
        }
    }

    private var documentDetailsSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            DocumentDetailRow(title: "Document", value: document.type.displayName)
            DocumentDetailRow(title: "File Name", value: document.name)
            DocumentDetailRow(title: "Status", value: document.status.displayName, color: document.status.color)
            DocumentDetailRow(title: "File Size", value: document.fileSize)
            DocumentDetailRow(title: "Uploaded", value: document.uploadedAt.formatted(date: .abbreviated, time: .shortened))
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var actionButtons: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Button(action: downloadPDF, label: {
                HStack {
                    Image(systemName: "arrow.down.circle")
                    Text("Download Document")
                }
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(ResponsiveDesign.spacing(16))
                .background(pdfData == nil ? Color.gray : AppTheme.accentLightBlue)
                .cornerRadius(ResponsiveDesign.spacing(12))
            })
            .disabled(pdfData == nil)
        }
    }

    private func downloadPDF() {
        guard let pdfData else { return }
        let sanitizedName = document.name.replacingOccurrences(of: ".pdf", with: "")
        PDFDownloadService.downloadPDFViaBrowser(pdfData, fileName: sanitizedName)
    }
}
