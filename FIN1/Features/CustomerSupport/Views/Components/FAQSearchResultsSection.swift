import SwiftUI

// MARK: - FAQ Search Results Section
/// Displays search results for FAQ articles

struct FAQSearchResultsSection: View {
    @ObservedObject var viewModel: FAQKnowledgeBaseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Suchergebnisse")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Text("\(viewModel.searchResults.count) Treffer")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            if viewModel.searchResults.isEmpty && !viewModel.isSearching {
                emptySearchResultView
            } else {
                ForEach(viewModel.searchResults) { result in
                    FAQSearchResultRow(result: result) {
                        viewModel.selectArticle(result.article)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var emptySearchResultView: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "magnifyingglass")
                .font(ResponsiveDesign.largeTitleFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.3))

            Text("Keine Artikel gefunden")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Text("Versuchen Sie andere Suchbegriffe")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(24))
    }
}

