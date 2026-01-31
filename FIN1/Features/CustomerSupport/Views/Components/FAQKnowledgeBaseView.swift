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
                    FAQSearchSection(viewModel: viewModel)
                    contentSection
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
                        dismiss()
                    }
                }

                if isCSRMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                viewModel.startCreateArticle()
                            } label: {
                                Label("Neuer Artikel", systemImage: "plus.circle")
                            }

                            Button {
                                Task { await viewModel.loadStatistics() }
                            } label: {
                                Label("Statistiken", systemImage: "chart.bar")
                            }

                            Divider()

                            Toggle(isOn: $viewModel.showUnpublished) {
                                Label("Entwürfe anzeigen", systemImage: "doc.badge.ellipsis")
                            }

                            Toggle(isOn: $viewModel.showArchived) {
                                Label("Archiviert anzeigen", systemImage: "archivebox")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.refresh() }
            .alert("Fehler", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "Ein Fehler ist aufgetreten")
            }
            .alert("Erfolg", isPresented: $viewModel.showSuccess) {
                Button("OK") { viewModel.clearSuccess() }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
            .sheet(isPresented: $viewModel.showArticleDetail) {
                if let article = viewModel.selectedArticle {
                    FAQArticleDetailView(
                        article: article,
                        viewModel: viewModel,
                        isCSRMode: isCSRMode,
                        userId: userId
                    )
                }
            }
            .sheet(isPresented: $viewModel.showCreateArticleSheet) {
                FAQArticleEditorSheet(viewModel: viewModel, isEditing: false)
            }
            .sheet(isPresented: $viewModel.showEditArticleSheet) {
                FAQArticleEditorSheet(viewModel: viewModel, isEditing: true)
            }
            .sheet(isPresented: $viewModel.showStatistics) {
                FAQStatisticsSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.isSearchActive {
            FAQSearchResultsSection(viewModel: viewModel)
        } else {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                if isCSRMode {
                    FAQStatisticsPreviewSection(viewModel: viewModel)
                }
                FAQCategoriesSection(viewModel: viewModel)
                FAQPopularArticlesSection(viewModel: viewModel, isCSRMode: isCSRMode)
                if isCSRMode && !viewModel.articlesNeedingReview.isEmpty {
                    FAQArticlesNeedingReviewSection(viewModel: viewModel)
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

