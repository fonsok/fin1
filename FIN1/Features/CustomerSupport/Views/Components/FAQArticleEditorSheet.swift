import SwiftUI

// MARK: - FAQ Article Editor Sheet
/// Sheet for creating or editing FAQ articles

struct FAQArticleEditorSheet: View {
    @ObservedObject var viewModel: FAQKnowledgeBaseViewModel
    let isEditing: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var services

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    // Title
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                        Text("Titel")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        TextField("Artikel-Titel", text: $viewModel.newArticleTitle)
                            .font(ResponsiveDesign.bodyFont())
                            .padding()
                            .background(AppTheme.inputFieldBackground)
                            .cornerRadius(ResponsiveDesign.spacing(8))
                    }

                    // Category
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                        Text("Kategorie")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        Picker("Kategorie", selection: $viewModel.newArticleCategory) {
                            ForEach(KnowledgeBaseCategory.allCases) { category in
                                HStack {
                                    Image(systemName: category.icon)
                                    Text(category.displayName)
                                }
                                .tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.inputFieldBackground)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                    }

                    // Summary
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                        Text("Zusammenfassung")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        TextField("Kurze Beschreibung", text: $viewModel.newArticleSummary, axis: .vertical)
                            .font(ResponsiveDesign.bodyFont())
                            .lineLimit(3...5)
                            .padding()
                            .background(AppTheme.inputFieldBackground)
                            .cornerRadius(ResponsiveDesign.spacing(8))
                    }

                    // Content
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                        Text("Inhalt")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        TextEditor(text: $viewModel.newArticleContent)
                            .font(ResponsiveDesign.bodyFont())
                            .frame(minHeight: ResponsiveDesign.spacing(200))
                            .padding(ResponsiveDesign.spacing(8))
                            .background(AppTheme.inputFieldBackground)
                            .cornerRadius(ResponsiveDesign.spacing(8))

                        Text("Markdown-Formatierung: ## Überschrift, - oder • für Listen")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                        Text("Tags (kommagetrennt)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        TextField("z.B. Login, Passwort, Sicherheit", text: Binding(
                            get: { viewModel.newArticleTags.joined(separator: ", ") },
                            set: { viewModel.newArticleTags = $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                        ))
                        .font(ResponsiveDesign.bodyFont())
                        .padding()
                        .background(AppTheme.inputFieldBackground)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                    }

                    // Keywords
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                        Text("Keywords (kommagetrennt)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        TextField("Suchbegriffe für bessere Auffindbarkeit", text: Binding(
                            get: { viewModel.newArticleKeywords.joined(separator: ", ") },
                            set: { viewModel.newArticleKeywords = $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                        ))
                        .font(ResponsiveDesign.bodyFont())
                        .padding()
                        .background(AppTheme.inputFieldBackground)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle(isEditing ? "Artikel bearbeiten" : "Neuer Artikel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Speichern" : "Erstellen") {
                        Task {
                            let userId = services.userService.currentUser?.id ?? "unknown"
                            if isEditing {
                                await viewModel.updateArticle(updatedBy: userId)
                            } else {
                                await viewModel.createArticle(createdBy: userId)
                            }
                        }
                    }
                    .disabled(viewModel.newArticleTitle.isEmpty || viewModel.newArticleContent.isEmpty)
                }
            }
        }
    }
}

