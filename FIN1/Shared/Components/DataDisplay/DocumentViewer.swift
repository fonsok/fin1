import SwiftUI

// MARK: - Document Viewer
/// Simple document viewer for non-Collection Bill documents
struct DocumentViewer: View {
    let document: Document
    @Environment(\.appServices) private var services

    private var navigationTitleKey: String {
        self.document.type == .investmentReservationEigenbeleg ? "Eigenbeleg" : "Document"
    }

    private var isInternalEigenbelegPlaceholder: Bool {
        self.document.type == .investmentReservationEigenbeleg
            && self.document.fileURL.hasPrefix("eigenbeleg-reservierung://")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(20)) {
                // Document Header
                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    Image(systemName: self.document.type.icon)
                        .font(ResponsiveDesign.titleFont())
                        .foregroundColor(self.document.type.color)

                    Text(self.document.type.displayName)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(.primary)

                    Text(self.document.name)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(ResponsiveDesign.spacing(20))
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))

                if let summary = document.accountingSummaryText?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !summary.isEmpty {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(10)) {
                        Text("Belegangaben (Buchhaltung)")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(.primary)
                        Text(summary)
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(ResponsiveDesign.spacing(16))
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                }

                // Document Details
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                    DocumentDetailRow(
                        title: "Status",
                        value: self.document.status.displayName,
                        valueColor: self.document.status.statusRowForeground
                    )
                    DocumentDetailRow(title: "File Size", value: self.document.fileSize)
                    DocumentDetailRow(title: "Uploaded", value: self.document.uploadedAt.formatted(date: .abbreviated, time: .shortened))

                    if let verifiedAt = document.verifiedAt {
                        DocumentDetailRow(title: "Verified", value: verifiedAt.formatted(date: .abbreviated, time: .shortened))
                    }

                    if let expiresAt = document.expiresAt {
                        DocumentDetailRow(title: "Expires", value: expiresAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                .padding(ResponsiveDesign.spacing(16))
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))

                // Action Buttons
                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    if self.isInternalEigenbelegPlaceholder {
                        Text("Kein PDF-Download: interner Eigenbeleg mit Buchungstext (siehe oben).")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(ResponsiveDesign.spacing(12))
                            .background(AppTheme.sectionBackground.opacity(0.6))
                            .cornerRadius(ResponsiveDesign.spacing(8))
                    } else {
                        Button(action: {
                            // TODO: Implement document download
                            print("Download document: \(self.document.name)")
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                Text("Download Document")
                            }
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)
                            .frame(maxWidth: .infinity)
                            .padding(ResponsiveDesign.spacing(16))
                            .background(AppTheme.accentLightBlue)
                            .cornerRadius(ResponsiveDesign.spacing(8))
                        }
                    }

                    if self.document.readAt == nil {
                        Button(action: {
                            self.services.documentService.markDocumentAsRead(self.document)
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Mark as Read")
                            }
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                            .frame(maxWidth: .infinity)
                            .padding(ResponsiveDesign.spacing(16))
                            .background(AppTheme.accentLightBlue.opacity(0.1))
                            .cornerRadius(ResponsiveDesign.spacing(8))
                        }
                    }
                }

                Spacer(minLength: ResponsiveDesign.spacing(20))
            }
            .padding(ResponsiveDesign.spacing(16))
        }
        .navigationTitle(self.navigationTitleKey)
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.systemSecondaryBackground)
    }
}

// MARK: - Document Detail Row
struct DocumentDetailRow: View {
    let title: String
    let value: String
    var valueColor: Color

    init(title: String, value: String, valueColor: Color = .primary) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        HStack {
            Text(self.title)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(.secondary)

            Spacer()

            Text(self.value)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(self.valueColor)
        }
    }
}
