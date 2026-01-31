import SwiftUI

// MARK: - Document Viewer
/// Simple document viewer for non-Collection Bill documents
struct DocumentViewer: View {
    let document: Document
    @Environment(\.appServices) private var services

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(20)) {
                // Document Header
                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    Image(systemName: document.type.icon)
                        .font(ResponsiveDesign.titleFont())
                        .foregroundColor(document.type.color)

                    Text(document.type.displayName)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(.primary)

                    Text(document.name)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(ResponsiveDesign.spacing(20))
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))

                // Document Details
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                    DocumentDetailRow(title: "Status", value: document.status.displayName, color: document.status.color)
                    DocumentDetailRow(title: "File Size", value: document.fileSize)
                    DocumentDetailRow(title: "Uploaded", value: document.uploadedAt.formatted(date: .abbreviated, time: .shortened))

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
                    Button(action: {
                        // TODO: Implement document download
                        print("Download document: \(document.name)")
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

                    if document.readAt == nil {
                        Button(action: {
                            services.documentService.markDocumentAsRead(document)
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
        .navigationTitle("Document")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.systemSecondaryBackground)
    }
}

// MARK: - Document Detail Row
struct DocumentDetailRow: View {
    let title: String
    let value: String
    let color: String?

    init(title: String, value: String, color: String? = nil) {
        self.title = title
        self.value = value
        self.color = color
    }

    var body: some View {
        HStack {
            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(color.map { Color($0) } ?? .primary)
        }
    }
}
