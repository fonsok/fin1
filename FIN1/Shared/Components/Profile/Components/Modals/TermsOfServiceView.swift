import SwiftUI

/// Terms of Service view displaying comprehensive terms and conditions
struct TermsOfServiceView: View {
    @ObservedObject private var viewModel: TermsOfServiceViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        configurationService: any ConfigurationServiceProtocol,
        termsContentService: (any TermsContentServiceProtocol)? = nil
    ) {
        self._viewModel = ObservedObject(wrappedValue: TermsOfServiceViewModel(
            configurationService: configurationService,
            termsContentService: termsContentService
        ))
    }

    @available(*, deprecated, message: "Inject dependencies via init(configurationService:termsContentService:) from AppServices.")
    init() {
        let defaultService = ConfigurationService(userService: UserService())
        self._viewModel = ObservedObject(wrappedValue: TermsOfServiceViewModel(configurationService: defaultService))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        self.headerSection
                        self.searchSection
                        self.controlsSection

                        if self.viewModel.hasNoSearchResults {
                            self.noResultsView
                        } else {
                            self.termsContent
                        }
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.top, ResponsiveDesign.spacing(16))
                    .padding(.bottom, ResponsiveDesign.spacing(24))
                }
            }
            .navigationTitle(self.navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(self.doneButtonTitle) {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }

    // MARK: - Localized Strings

    private var isEnglish: Bool {
        self.viewModel.currentLanguage == .english
    }

    private var displayedVersion: String {
        self.viewModel.displayedVersion
    }

    private var displayedLastUpdatedText: String {
        self.viewModel.displayedLastUpdatedText
    }

    private var navigationTitle: String {
        self.isEnglish ? "Terms of Service" : "Nutzungsbedingungen"
    }

    private var doneButtonTitle: String {
        self.isEnglish ? "Done" : "Fertig"
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentOrange)

                Text(self.navigationTitle)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()
            }

            Text(self.isEnglish
                ? "Last Updated: \(self.displayedLastUpdatedText) | Version: \(self.displayedVersion)"
                : "Zuletzt aktualisiert: \(self.displayedLastUpdatedText) | Version: \(self.displayedVersion)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Text(self.isEnglish
                ? "Please read these terms carefully. By using the \(LegalIdentity.platformName) App, you agree to be bound by these Terms of Service."
                : "Bitte lesen Sie diese Bedingungen sorgfältig. Durch die Nutzung der \(LegalIdentity.platformName)-App erklären Sie sich damit einverstanden, an diese Nutzungsbedingungen gebunden zu sein.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.leading)
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Search Section

    private var searchSection: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.fontColor.opacity(0.6))

            TextField(self.isEnglish ? "Search terms..." : "Begriffe suchen...", text: self.$viewModel.searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(AppTheme.fontColor)

            if !self.viewModel.searchQuery.isEmpty {
                Button(action: { self.viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
            }
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.systemTertiaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Button(action: { self.viewModel.expandAll() }) {
                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: "chevron.down.circle")
                        .font(ResponsiveDesign.captionFont())
                    Text(self.isEnglish ? "Expand All" : "Alle öffnen")
                        .font(ResponsiveDesign.captionFont())
                }
                .foregroundColor(AppTheme.accentLightBlue)
            }

            Button(action: { self.viewModel.collapseAll() }) {
                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: "chevron.up.circle")
                        .font(ResponsiveDesign.captionFont())
                    Text(self.isEnglish ? "Collapse All" : "Alle schließen")
                        .font(ResponsiveDesign.captionFont())
                }
                .foregroundColor(AppTheme.accentLightBlue)
            }

            Button(action: { self.viewModel.toggleLanguage() }) {
                Text(self.viewModel.currentLanguage.oppositeFlag)
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 1.2))
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
    }

    // MARK: - Terms Content

    private var termsContent: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            ForEach(self.viewModel.filteredSections) { section in
                TermsSectionRow(
                    section: section,
                    isExpanded: self.viewModel.isExpanded(section),
                    onToggle: { self.viewModel.toggleSection(section) }
                )
            }
        }
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "magnifyingglass")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2.4))
                .foregroundColor(AppTheme.fontColor.opacity(0.5))

            Text(self.isEnglish ? "No Results Found" : "Keine Ergebnisse gefunden")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text(self.isEnglish
                ? "Try searching with different keywords"
                : "Versuchen Sie es mit anderen Suchbegriffen")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(ResponsiveDesign.spacing(32))
    }
}

// MARK: - Terms Section Row

private struct TermsSectionRow: View {
    let section: TermsOfServiceViewModel.TermsSection
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        ExpandableSectionRow(
            title: self.section.title,
            icon: nil, // Icons removed to match FAQ styling
            iconColor: AppTheme.accentLightBlue,
            isExpanded: self.isExpanded,
            onToggle: self.onToggle,
            titleFontWeight: ResponsiveDesign.faqQuestionFontWeight
        ) {
            TermsContentView(text: self.section.content)
        }
    }
}

// MARK: - Terms Content View (Formatted Text)

private struct TermsContentView: View {
    let text: String

    var body: some View {
        LegalDocumentFormatter(text: self.text)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    TermsOfServiceView(
        configurationService: ConfigurationService(userService: UserService()),
        termsContentService: TermsContentService(parseAPIClient: nil)
    )
}
#endif
