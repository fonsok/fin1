import SwiftUI

// MARK: - FAQ Knowledge Base View
/// Main view for browsing and managing FAQ articles
/// Used by CSRs to find solutions and by users to self-serve

struct FAQKnowledgeBaseView: View {
    @StateObject private var viewModel: FAQKnowledgeBaseViewModel
    @Environment(\.dismiss) private var dismiss

    private let isCSRMode: Bool
    private let userId: String?

    init(
        faqService: FAQKnowledgeBaseServiceProtocol,
        auditService: AuditLoggingServiceProtocol,
        isCSRMode: Bool = true,
        userId: String? = nil
    ) {
        _viewModel = StateObject(wrappedValue: FAQKnowledgeBaseViewModel(
            faqService: faqService,
            auditService: auditService
        ))
        self.isCSRMode = isCSRMode
        self.userId = userId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    FAQSearchSection(viewModel: self.viewModel)
                    self.contentSection
                }
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                .padding(.top, ResponsiveDesign.spacing(8))
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("FAQ Wissensdatenbank")
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
                                self.viewModel.startCreateArticle()
                            } label: {
                                Label("Neuer Artikel", systemImage: "plus.circle")
                            }

                            Button {
                                Task { await self.viewModel.loadStatistics() }
                            } label: {
                                Label("Statistiken", systemImage: "chart.bar")
                            }

                            Divider()

                            Toggle(isOn: self.$viewModel.showUnpublished) {
                                Label("Entwürfe anzeigen", systemImage: "doc.badge.ellipsis")
                            }

                            Toggle(isOn: self.$viewModel.showArchived) {
                                Label("Archiviert anzeigen", systemImage: "archivebox")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .task { await self.viewModel.load() }
            .refreshable { await self.viewModel.refresh() }
            .alert("Fehler", isPresented: self.$viewModel.showError) {
                Button("OK") { self.viewModel.clearError() }
            } message: {
                Text(self.viewModel.errorMessage ?? "Ein Fehler ist aufgetreten")
            }
            .alert("Erfolg", isPresented: self.$viewModel.showSuccess) {
                Button("OK") { self.viewModel.clearSuccess() }
            } message: {
                Text(self.viewModel.successMessage ?? "")
            }
            .sheet(isPresented: self.$viewModel.showArticleDetail) {
                if let article = viewModel.selectedArticle {
                    FAQArticleDetailView(
                        article: article,
                        viewModel: self.viewModel,
                        isCSRMode: self.isCSRMode,
                        userId: self.userId
                    )
                }
            }
            .sheet(isPresented: self.$viewModel.showCreateArticleSheet) {
                FAQArticleEditorSheet(viewModel: self.viewModel, isEditing: false)
            }
            .sheet(isPresented: self.$viewModel.showEditArticleSheet) {
                FAQArticleEditorSheet(viewModel: self.viewModel, isEditing: true)
            }
            .sheet(isPresented: self.$viewModel.showStatistics) {
                FAQStatisticsSheet(viewModel: self.viewModel)
            }
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        if self.viewModel.isSearchActive {
            FAQSearchResultsSection(viewModel: self.viewModel)
        } else {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                if self.isCSRMode {
                    FAQStatisticsPreviewSection(viewModel: self.viewModel)
                }
                FAQCategoriesSection(viewModel: self.viewModel)
                FAQPopularArticlesSection(viewModel: self.viewModel, isCSRMode: self.isCSRMode)
                if self.isCSRMode && !self.viewModel.articlesNeedingReview.isEmpty {
                    FAQArticlesNeedingReviewSection(viewModel: self.viewModel)
                }
            }
        }
    }
}


// MARK: - Preview

#Preview {
    FAQKnowledgeBaseView(
        faqService: FAQKnowledgeBaseService(auditService: AuditLoggingService()),
        auditService: AuditLoggingService(),
        isCSRMode: true
    )
}

