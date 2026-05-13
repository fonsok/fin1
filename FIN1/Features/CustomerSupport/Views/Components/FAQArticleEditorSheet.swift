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

                        TextField("Artikel-Titel", text: self.$viewModel.newArticleTitle)
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

                        Picker("Kategorie", selection: self.$viewModel.newArticleCategory) {
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

                        TextField("Kurze Beschreibung", text: self.$viewModel.newArticleSummary, axis: .vertical)
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

                        TextEditor(text: self.$viewModel.newArticleContent)
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
                            get: { self.viewModel.newArticleTags.joined(separator: ", ") },
                            set: { self.viewModel.newArticleTags = $0.components(separatedBy: ",").map { $0.trimmingCharacters(
                                in: .whitespaces
                            ) }.filter { !$0.isEmpty } }
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
                            get: { self.viewModel.newArticleKeywords.joined(separator: ", ") },
                            set: { self.viewModel.newArticleKeywords = $0.components(separatedBy: ",").map { $0.trimmingCharacters(
                                in: .whitespaces
                            ) }.filter { !$0.isEmpty } }
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
            .navigationTitle(self.isEditing ? "Artikel bearbeiten" : "Neuer Artikel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        self.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(self.isEditing ? "Speichern" : "Erstellen") {
                        Task {
                            let userId = self.services.userService.currentUser?.id ?? "unknown"
                            if self.isEditing {
                                await self.viewModel.updateArticle(updatedBy: userId)
                            } else {
                                await self.viewModel.createArticle(createdBy: userId)
                            }
                        }
                    }
                    .disabled(self.viewModel.newArticleTitle.isEmpty || self.viewModel.newArticleContent.isEmpty)
                }
            }
        }
    }
}

