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
                    self.headerSection
                    self.contentSection
                    self.feedbackSection
                    if self.isCSRMode {
                        self.metadataSection
                        self.actionsSection
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
                        self.dismiss()
                    }
                }

                if self.isCSRMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                self.viewModel.startEditArticle(self.article)
                            } label: {
                                Label("Bearbeiten", systemImage: "pencil")
                            }

                            if self.article.isPublished {
                                Button {
                                    Task { await self.viewModel.unpublishArticle(self.article) }
                                } label: {
                                    Label("Als Entwurf", systemImage: "doc.badge.ellipsis")
                                }
                            } else {
                                Button {
                                    Task { await self.viewModel.publishArticle(self.article) }
                                } label: {
                                    Label("Veröffentlichen", systemImage: "checkmark.circle")
                                }
                            }

                            Divider()

                            Button {
                                Task { await self.viewModel.archiveArticle(self.article) }
                            } label: {
                                Label("Archivieren", systemImage: "archivebox")
                            }

                            Button(role: .destructive) {
                                self.showDeleteConfirmation = true
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("Artikel löschen?", isPresented: self.$showDeleteConfirmation) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    Task {
                        await self.viewModel.deleteArticle(self.article)
                        self.dismiss()
                    }
                }
            } message: {
                Text("Dieser Vorgang kann nicht rückgängig gemacht werden.")
            }
            .sheet(isPresented: self.$showFeedbackSheet) {
                FAQFeedbackSheet(article: self.article, viewModel: self.viewModel, userId: self.userId)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: self.article.category.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(Color(hex: self.article.category.color))

                Text(self.article.category.displayName)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(Color(hex: self.article.category.color))

                Spacer()

                if !self.article.isPublished {
                    Text("Entwurf")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.white)
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                        .background(AppTheme.accentOrange)
                        .cornerRadius(ResponsiveDesign.spacing(4))
                }

                if self.article.isArchived {
                    Text("Archiviert")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.white)
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                        .background(AppTheme.fontColor.opacity(0.5))
                        .cornerRadius(ResponsiveDesign.spacing(4))
                }
            }

            Text(self.article.title)
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text(self.article.summary)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            // Stats row
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                Label("\(self.article.viewCount) Aufrufe", systemImage: "eye")
                Label("\(self.article.helpfulnessPercentage)% hilfreich", systemImage: "hand.thumbsup")
                Label("\(self.article.usedInTicketCount)x verwendet", systemImage: "ticket")
            }
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.6))

            // Tags
            if !self.article.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ResponsiveDesign.spacing(8)) {
                        ForEach(self.article.tags, id: \.self) { tag in
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
            ForEach(self.parseContent(self.article.content), id: \.self) { block in
                self.contentBlockView(block)
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
                        await self.viewModel.submitFeedback(
                            forArticle: self.article,
                            isHelpful: true,
                            comment: nil,
                            userId: self.userId
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
                    self.showFeedbackSheet = true
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
                FAQMetadataRow(label: "Erstellt", value: self.viewModel.formattedDate(self.article.createdAt))
                FAQMetadataRow(label: "Erstellt von", value: self.article.createdBy)
                FAQMetadataRow(label: "Aktualisiert", value: self.viewModel.formattedDate(self.article.updatedAt))

                if let updatedBy = article.lastUpdatedBy {
                    FAQMetadataRow(label: "Aktualisiert von", value: updatedBy)
                }

                if let solutionType = article.solutionType {
                    FAQMetadataRow(label: "Lösungstyp", value: solutionType.displayName)
                }

                if !self.article.sourceTicketIds.isEmpty {
                    FAQMetadataRow(label: "Quell-Tickets", value: "\(self.article.sourceTicketIds.count)")
                }

                if !self.article.keywords.isEmpty {
                    FAQMetadataRow(label: "Keywords", value: self.article.keywords.joined(separator: ", "))
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
                    UIPasteboard.general.string = self.article.content
                }

                FAQActionButton(
                    icon: "square.and.arrow.up",
                    title: "Teilen",
                    color: AppTheme.accentGreen
                ) {
                    // Share functionality
                }

                if self.article.relatedHelpCenterArticleId != nil {
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

