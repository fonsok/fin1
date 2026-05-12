import SwiftUI

/// Imprint / Impressum view (server-driven via TermsContentService)
struct ImprintView: View {
    @StateObject private var viewModel: ImprintViewModel
    @Environment(\.dismiss) private var dismiss

    init(termsContentService: any TermsContentServiceProtocol) {
        _viewModel = StateObject(wrappedValue: ImprintViewModel(
            termsContentService: termsContentService
        ))
    }

    @available(*, deprecated, message: "Inject dependencies via init(termsContentService:) from AppServices.")
    init() {
        _viewModel = StateObject(wrappedValue: ImprintViewModel(termsContentService: nil))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        headerSection
                        searchSection
                        controlsSection

                        if viewModel.hasNoSearchResults {
                            noResultsView
                        } else {
                            contentSection
                        }
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.top, ResponsiveDesign.spacing(16))
                    .padding(.bottom, ResponsiveDesign.spacing(24))
                }
            }
            .navigationTitle(viewModel.currentLanguage == .german ? "Impressum" : "Imprint")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(viewModel.currentLanguage == .german ? "Fertig" : "Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "building.2.fill")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentLightBlue)

                Text(viewModel.currentLanguage == .german ? "Impressum" : "Imprint")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()
            }

            Text(viewModel.currentLanguage == .german
                 ? "Stand: \(viewModel.displayedLastUpdatedText) | Version: \(viewModel.displayedVersion)"
                 : "Last Updated: \(viewModel.displayedLastUpdatedText) | Version: \(viewModel.displayedVersion)")
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var searchSection: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.fontColor.opacity(0.6))

            TextField(
                viewModel.currentLanguage == .german ? "Impressum durchsuchen..." : "Search imprint...",
                text: $viewModel.searchQuery
            )
            .textFieldStyle(PlainTextFieldStyle())
            .foregroundColor(AppTheme.fontColor)

            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
            }
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.systemTertiaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }

    private var controlsSection: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Button(action: { viewModel.expandAll() }) {
                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: "chevron.down.circle")
                        .font(ResponsiveDesign.captionFont())
                    Text(viewModel.currentLanguage == .german ? "Alle öffnen" : "Expand All")
                        .font(ResponsiveDesign.captionFont())
                }
                .foregroundColor(AppTheme.accentLightBlue)
            }

            Button(action: { viewModel.collapseAll() }) {
                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: "chevron.up.circle")
                        .font(ResponsiveDesign.captionFont())
                    Text(viewModel.currentLanguage == .german ? "Alle schließen" : "Collapse All")
                        .font(ResponsiveDesign.captionFont())
                }
                .foregroundColor(AppTheme.accentLightBlue)
            }

            Button(action: { viewModel.toggleLanguage() }) {
                Text(viewModel.currentLanguage == .english ? "🇩🇪" : "🇬🇧")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 1.2))
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
    }

    private var contentSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            ForEach(viewModel.filteredSections) { section in
                ExpandableSectionRow(
                    title: section.title,
                    icon: nil,
                    iconColor: AppTheme.accentLightBlue,
                    isExpanded: viewModel.isExpanded(section),
                    onToggle: { viewModel.toggleSection(section) },
                    titleFontWeight: ResponsiveDesign.faqQuestionFontWeight
                ) {
                    LegalDocumentFormatter(text: section.content)
                }
            }
        }
    }

    private var noResultsView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "magnifyingglass")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2.4))
                .foregroundColor(AppTheme.fontColor.opacity(0.5))

            Text(viewModel.currentLanguage == .german ? "Keine Ergebnisse gefunden" : "No Results Found")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text(viewModel.currentLanguage == .german ? "Versuchen Sie andere Suchbegriffe" : "Try searching with different keywords")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(ResponsiveDesign.spacing(32))
    }

    // Date formatting lives in the ViewModel (MVVM).
}

#if DEBUG
#Preview {
    ImprintView(termsContentService: TermsContentService(parseAPIClient: nil))
}
#endif

