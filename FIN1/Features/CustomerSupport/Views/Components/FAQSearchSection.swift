import SwiftUI

// MARK: - FAQ Search Section
/// Search interface for FAQ articles

struct FAQSearchSection: View {
    @ObservedObject var viewModel: FAQKnowledgeBaseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))

                TextField("FAQ durchsuchen...", text: self.$viewModel.searchQuery)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                if self.viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                if !self.viewModel.searchQuery.isEmpty {
                    Button {
                        self.viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(AppTheme.inputFieldBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

