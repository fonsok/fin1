import SwiftUI

// MARK: - FAQ Article Detail View
/// Detailed view of an FAQ article with feedback options

struct FAQArticleDetailView: View {
    let article: FAQArticle
    @ObservedObject var viewModel: FAQKnowledgeBaseViewModel
    let isCSRMode: Bool
    let userId: String?

    @Environment(\.dismiss) private var dismiss
    @State private var showFeedbackSheet = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                    headerSection
                    contentSection
                    feedbackSection
                    if isCSRMode {
                        metadataSection
                        actionsSection
                    }
                }
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                .padding(.top, ResponsiveDesign.spacing(8))
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("FAQ Artikel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") {
                        dismiss()
                    }
                }

                if isCSRMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                viewModel.startEditArticle(article)
                            } label: {
                                Label("Bearbeiten", systemImage: "pencil")
                            }

                            if article.isPublished {
                                Button {
                                    Task { await viewModel.unpublishArticle(article) }
                                } label: {
                                    Label("Als Entwurf", systemImage: "doc.badge.ellipsis")
                                }
                            } else {
                                Button {
                                    Task { await viewModel.publishArticle(article) }
                                } label: {
                                    Label("Veröffentlichen", systemImage: "checkmark.circle")
                                }
                            }

                            Divider()

                            Button {
                                Task { await viewModel.archiveArticle(article) }
                            } label: {
                                Label("Archivieren", systemImage: "archivebox")
                            }

                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("Artikel löschen?", isPresented: $showDeleteConfirmation) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    Task {
                        await viewModel.deleteArticle(article)
                        dismiss()
                    }
                }
            } message: {
                Text("Dieser Vorgang kann nicht rückgängig gemacht werden.")
            }
            .sheet(isPresented: $showFeedbackSheet) {
                FAQFeedbackSheet(article: article, viewModel: viewModel, userId: userId)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: article.category.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(Color(hex: article.category.color))

                Text(article.category.displayName)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(Color(hex: article.category.color))

                Spacer()

                if !article.isPublished {
                    Text("Entwurf")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.white)
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                        .background(AppTheme.accentOrange)
                        .cornerRadius(ResponsiveDesign.spacing(4))
                }

                if article.isArchived {
                    Text("Archiviert")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.white)
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                        .background(AppTheme.fontColor.opacity(0.5))
                        .cornerRadius(ResponsiveDesign.spacing(4))
                }
            }

            Text(article.title)
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text(article.summary)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            // Stats row
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                Label("\(article.viewCount) Aufrufe", systemImage: "eye")
                Label("\(article.helpfulnessPercentage)% hilfreich", systemImage: "hand.thumbsup")
                Label("\(article.usedInTicketCount)x verwendet", systemImage: "ticket")
            }
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.6))

            // Tags
            if !article.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ResponsiveDesign.spacing(8)) {
                        ForEach(article.tags, id: \.self) { tag in
                            Text(tag)
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.accentLightBlue)
                                .padding(.horizontal, ResponsiveDesign.spacing(8))
                                .padding(.vertical, ResponsiveDesign.spacing(4))
                                .background(AppTheme.accentLightBlue.opacity(0.15))
                                .cornerRadius(ResponsiveDesign.spacing(4))
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Inhalt")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            // Simple markdown-like rendering
            ForEach(parseContent(article.content), id: \.self) { block in
                contentBlockView(block)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    @ViewBuilder
    private func contentBlockView(_ block: ContentBlock) -> some View {
        switch block.type {
        case .heading:
            Text(block.text)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)
                .padding(.top, ResponsiveDesign.spacing(8))

        case .paragraph:
            Text(block.text)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.9))
                .lineSpacing(ResponsiveDesign.spacing(4))

        case .listItem:
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(8)) {
                Text("•")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.accentLightBlue)

                Text(block.text)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.9))
            }

        case .numberedItem:
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(8)) {
                Text(block.prefix ?? "")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.accentLightBlue)
                    .frame(width: ResponsiveDesign.spacing(20), alignment: .trailing)

                Text(block.text)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.9))
            }
        }
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("War dieser Artikel hilfreich?")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            HStack(spacing: ResponsiveDesign.spacing(16)) {
                Button {
                    Task {
                        await viewModel.submitFeedback(
                            forArticle: article,
                            isHelpful: true,
                            comment: nil,
                            userId: userId
                        )
                    }
                } label: {
                    HStack {
                        Image(systemName: "hand.thumbsup.fill")
                        Text("Ja")
                    }
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.white)
                    .padding(.horizontal, ResponsiveDesign.spacing(20))
                    .padding(.vertical, ResponsiveDesign.spacing(12))
                    .background(AppTheme.accentGreen)
                    .cornerRadius(ResponsiveDesign.spacing(8))
                }

                Button {
                    showFeedbackSheet = true
                } label: {
                    HStack {
                        Image(systemName: "hand.thumbsdown.fill")
                        Text("Nein")
                    }
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.white)
                    .padding(.horizontal, ResponsiveDesign.spacing(20))
                    .padding(.vertical, ResponsiveDesign.spacing(12))
                    .background(AppTheme.accentRed)
                    .cornerRadius(ResponsiveDesign.spacing(8))
                }

                Spacer()
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Metadata Section (CSR Only)

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Metadaten")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    FAQMetadataRow(label: "Erstellt", value: viewModel.formattedDate(article.createdAt))
                    FAQMetadataRow(label: "Erstellt von", value: article.createdBy)
                    FAQMetadataRow(label: "Aktualisiert", value: viewModel.formattedDate(article.updatedAt))

                    if let updatedBy = article.lastUpdatedBy {
                        FAQMetadataRow(label: "Aktualisiert von", value: updatedBy)
                    }

                    if let solutionType = article.solutionType {
                        FAQMetadataRow(label: "Lösungstyp", value: solutionType.displayName)
                    }

                    if !article.sourceTicketIds.isEmpty {
                        FAQMetadataRow(label: "Quell-Tickets", value: "\(article.sourceTicketIds.count)")
                    }

                    if !article.keywords.isEmpty {
                        FAQMetadataRow(label: "Keywords", value: article.keywords.joined(separator: ", "))
                    }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Actions Section (CSR Only)

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Aktionen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                FAQActionButton(
                    icon: "doc.on.doc",
                    title: "Kopieren",
                    color: AppTheme.accentLightBlue
                ) {
                    UIPasteboard.general.string = article.content
                }

                FAQActionButton(
                    icon: "square.and.arrow.up",
                    title: "Teilen",
                    color: AppTheme.accentGreen
                ) {
                    // Share functionality
                }

                if article.relatedHelpCenterArticleId != nil {
                    FAQActionButton(
                        icon: "link",
                        title: "Help Center",
                        color: AppTheme.accentOrange
                    ) {
                        // Open Help Center article
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Helpers

    private func parseContent(_ content: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let lines = content.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                continue
            } else if trimmed.hasPrefix("## ") {
                blocks.append(ContentBlock(type: .heading, text: String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("• ") || trimmed.hasPrefix("- ") {
                blocks.append(ContentBlock(type: .listItem, text: String(trimmed.dropFirst(2))))
            } else if let match = trimmed.firstMatch(of: /^(\d+)\.\s+(.+)/) {
                blocks.append(ContentBlock(
                    type: .numberedItem,
                    text: String(match.2),
                    prefix: String(match.1) + "."
                ))
            } else {
                blocks.append(ContentBlock(type: .paragraph, text: trimmed))
            }
        }

        return blocks
    }
}


// MARK: - Preview

#Preview {
    FAQArticleDetailView(
        article: FAQKnowledgeBaseService.createMockArticles()[0],
        viewModel: FAQKnowledgeBaseViewModel(
            faqService: FAQKnowledgeBaseService(auditService: AuditLoggingService()),
            auditService: AuditLoggingService()
        ),
        isCSRMode: true,
        userId: nil
    )
}

