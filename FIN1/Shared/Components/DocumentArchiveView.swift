import SwiftUI

struct DocumentArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @State private var selectedFilter: DocumentType?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    // Filter Header
                    filterHeader

                    // Archived Documents List
                    ScrollView {
                        LazyVStack(spacing: ResponsiveDesign.spacing(16)) {
                            ForEach(filteredArchivedDocuments) { document in
                                ArchivedDocumentCard(document: document)
                            }

                            if filteredArchivedDocuments.isEmpty {
                                emptyStateView
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Document Archive")
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            })
        }
    }

    // MARK: - Filter Header
    private var filterHeader: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            // Quick Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    // All documents filter
                    DocumentFilterPill(
                        title: "All",
                        isSelected: selectedFilter == nil
                    ) {
                        selectedFilter = nil
                    }

                    // Document type filters
                    ForEach(DocumentType.allCases, id: \.self) { documentType in
                        DocumentFilterPill(
                            title: documentType.rawValue,
                            isSelected: selectedFilter == documentType
                        ) {
                            selectedFilter = documentType
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 16)
        .background(AppTheme.screenBackground)
    }

    // MARK: - Filtered Archived Documents
    private var filteredArchivedDocuments: [Document] {
        let allDocuments = appServices.documentService.getDocuments(for: appServices.userService.currentUser?.id ?? "")

        // Get documents that are older than 24 hours after being read
        let archivedDocuments = allDocuments.filter { document in
            guard let readAt = document.readAt else { return false }
            return Date().timeIntervalSince(readAt) > 86400 // 24 hours
        }

        // Apply type filter if selected
        if let selectedFilter = selectedFilter {
            return archivedDocuments.filter { $0.type == selectedFilter }
        }

        return archivedDocuments
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.fontColor.opacity(0.3))

            Text("No Archived Documents")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text("Documents appear here 24 hours after being marked as read")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(ResponsiveDesign.spacing(32))
    }
}

// MARK: - Document Filter Pill
struct DocumentFilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action, label: {
            Text(title)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .foregroundColor(isSelected ? AppTheme.screenBackground : AppTheme.accentLightBlue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppTheme.accentLightBlue : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(20))
                        .stroke(AppTheme.accentLightBlue, lineWidth: 1)
                )
                .cornerRadius(ResponsiveDesign.spacing(20))
        })
    }
}

// MARK: - Archived Document Card
struct ArchivedDocumentCard: View {
    let document: Document
    @Environment(\.appServices) private var appServices

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                // Icon
                Image(systemName: document.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(document.type.color)
                    .frame(width: 40, height: 40)
                    .background(document.type.color.opacity(0.1))
                    .clipShape(Circle())

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(document.title)
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        Spacer()

                        // Archived indicator
                        Image(systemName: "archivebox.fill")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }

                    Text(document.description)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Text(document.timestamp, style: .date)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                            .textCase(.uppercase)

                        Spacer()

                        Text("\(document.fileSize) • \(document.fileFormat)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Button(action: {
                    Task {
                        do {
                            _ = try await appServices.documentService.downloadDocument(document)
                            // Handle successful download if needed
                        } catch {
                            // Handle download error if needed
                            print("Download failed: \(error)")
                        }
                    }
                }) {
                    HStack {
                        if document.downloadedAt != nil {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Downloaded")
                        } else {
                            Image(systemName: "arrow.down.circle")
                            Text("Download")
                        }
                    }
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(document.downloadedAt != nil ? AppTheme.accentLightBlue : AppTheme.accentGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background((document.downloadedAt != nil ? AppTheme.accentLightBlue : AppTheme.accentGreen).opacity(0.1))
                    .cornerRadius(ResponsiveDesign.spacing(6))
                }
                .disabled(document.downloadedAt != nil)

                Spacer()
            }
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground.opacity(0.7))
        .cornerRadius(ResponsiveDesign.spacing(12))
        .opacity(0.8)
    }
}

#Preview {
    DocumentArchiveView()
}
