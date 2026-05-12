import SwiftUI

/// Privacy Policy view displaying comprehensive privacy and data protection information
/// Shows American version (English, US law) or German version (German, EU/German law) based on user jurisdiction
struct PrivacyPolicyView: View {
    @StateObject private var viewModel: PrivacyPolicyViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        userService: any UserServiceProtocol,
        termsContentService: any TermsContentServiceProtocol
    ) {
        _viewModel = StateObject(wrappedValue: PrivacyPolicyViewModel(
            userService: userService,
            termsContentService: termsContentService
        ))
    }

    @available(*, deprecated, message: "Inject dependencies via init(userService:termsContentService:) from AppServices.")
    init() {
        _viewModel = StateObject(wrappedValue: PrivacyPolicyViewModel(userService: nil, termsContentService: nil))
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
                            privacyContent
                        }
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.top, ResponsiveDesign.spacing(16))
                    .padding(.bottom, ResponsiveDesign.spacing(24))
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(doneButtonTitle) {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }

    // MARK: - Localized Strings

    private var displayedVersion: String {
        viewModel.displayedVersion
    }

    private var displayedLastUpdatedText: String {
        viewModel.displayedLastUpdatedText
    }

    private var navigationTitle: String {
        viewModel.isAmericanVersion ? "Privacy Policy" : "Datenschutzerklärung"
    }

    private var doneButtonTitle: String {
        viewModel.isAmericanVersion ? "Done" : "Fertig"
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "hand.raised.slash.fill")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentRed)

                Text(navigationTitle)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()
            }

            Text(viewModel.isAmericanVersion
                 ? "Last Updated: \(displayedLastUpdatedText) | Version: \(displayedVersion)"
                 : "Zuletzt aktualisiert: \(displayedLastUpdatedText) | Version: \(displayedVersion)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Text(viewModel.isAmericanVersion
                 ? "This Privacy Policy describes how we collect, use, store, and protect your personal information in compliance with CCPA, CPRA, and applicable U.S. privacy laws."
                 : "Diese Datenschutzerklärung beschreibt, wie wir Ihre personenbezogenen Daten in Übereinstimmung mit der DSGVO und geltenden Datenschutzgesetzen sammeln, verwenden, speichern und schützen.")
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

            TextField(viewModel.isAmericanVersion ? "Search privacy policy..." : "Datenschutzerklärung durchsuchen...", text: $viewModel.searchQuery)
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

    // MARK: - Controls Section

    private var controlsSection: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Button(action: { viewModel.expandAll() }) {
                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: "chevron.down.circle")
                        .font(ResponsiveDesign.captionFont())
                    Text(viewModel.isAmericanVersion ? "Expand All" : "Alle öffnen")
                        .font(ResponsiveDesign.captionFont())
                }
                .foregroundColor(AppTheme.accentLightBlue)
            }

            Button(action: { viewModel.collapseAll() }) {
                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: "chevron.up.circle")
                        .font(ResponsiveDesign.captionFont())
                    Text(viewModel.isAmericanVersion ? "Collapse All" : "Alle schließen")
                        .font(ResponsiveDesign.captionFont())
                }
                .foregroundColor(AppTheme.accentLightBlue)
            }

            // Jurisdiction toggle for testing
            Button(action: { viewModel.toggleJurisdiction() }) {
                Text(viewModel.isAmericanVersion ? "🇩🇪" : "🇺🇸")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 1.2))
            }
            .buttonStyle(PlainButtonStyle())
            .help(viewModel.isAmericanVersion ? "Switch to German version" : "Switch to American version")

            Spacer()
        }
    }

    // MARK: - Privacy Content

    private var privacyContent: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            ForEach(viewModel.filteredSections) { section in
                PrivacySectionRow(
                    section: section,
                    isExpanded: viewModel.isExpanded(section),
                    onToggle: { viewModel.toggleSection(section) }
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

            Text(viewModel.isAmericanVersion ? "No Results Found" : "Keine Ergebnisse gefunden")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text(viewModel.isAmericanVersion
                 ? "Try searching with different keywords"
                 : "Versuchen Sie es mit anderen Suchbegriffen")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(ResponsiveDesign.spacing(32))
    }
}

// MARK: - Privacy Section Row

private struct PrivacySectionRow: View {
    let section: PrivacyPolicyViewModel.PrivacySection
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        ExpandableSectionRow(
            title: section.title,
            icon: nil, // Icons removed as requested
            iconColor: AppTheme.accentRed,
            isExpanded: isExpanded,
            onToggle: onToggle,
            titleFontWeight: ResponsiveDesign.faqQuestionFontWeight
        ) {
            PrivacyContentView(text: section.content)
        }
    }
}

// MARK: - Privacy Content View (Formatted Text)

private struct PrivacyContentView: View {
    let text: String

    var body: some View {
        LegalDocumentFormatter(text: text)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    PrivacyPolicyView(
        userService: UserService(),
        termsContentService: TermsContentService(parseAPIClient: nil)
    )
}
#endif

