import SwiftUI

/// Help Center view displaying searchable and categorized FAQs
struct HelpCenterView: View {
    @StateObject private var viewModel: HelpCenterViewModel
    @Environment(\.dismiss) private var dismiss

    private var isGerman: Bool {
        Locale.current.language.languageCode?.identifier == "de"
    }

    init(userRole: UserRole? = nil) {
        let services = AppServices.live
        let role = userRole ?? (services.userService as? UserService)?.currentUser?.role
        self._viewModel = StateObject(wrappedValue: HelpCenterViewModel(
            faqContentService: FAQContentService(
                parseAPIClient: services.parseAPIClient,
                configurationService: services.configurationService
            ),
            userRole: role?.rawValue
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        // Search Bar
                        searchSection

                        // Category Filter
                        if !viewModel.categories.isEmpty {
                            categoryFilterSection
                        }

                        // Content
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(AppTheme.accentLightBlue)
                                .padding(.top, ResponsiveDesign.spacing(24))
                        } else if viewModel.hasNoFAQs {
                            unavailableView
                        } else if viewModel.hasNoSearchResults {
                            noResultsView
                        } else if !viewModel.searchQuery.isEmpty {
                            searchResultsView
                        } else {
                            categoryBasedView
                        }
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.top, ResponsiveDesign.spacing(16))
                    .padding(.bottom, ResponsiveDesign.spacing(24))
                }
                .refreshable {
                    await viewModel.reload()
                }
            }
            .navigationTitle(isGerman ? "Hilfe" : "Help Center")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isGerman ? "Fertig" : "Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }

    // MARK: - Search Section

    private var searchSection: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.fontColor.opacity(0.6))

            TextField(isGerman ? "FAQs durchsuchen..." : "Search FAQs...", text: $viewModel.searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(AppTheme.fontColor)
                .onChange(of: viewModel.searchQuery) { _, newValue in
                    // Clear category selection when searching
                    if !newValue.isEmpty {
                        viewModel.selectCategory(nil)
                    }
                }

            if !viewModel.searchQuery.isEmpty {
                Button(action: {
                    viewModel.searchQuery = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
            }
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.systemTertiaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }

    // MARK: - Category Filter

    private var categoryFilterSection: some View {
        let columns = adaptiveGridColumns()
        let gridSpacing = ResponsiveDesign.spacing(12)

        return LazyVGrid(
            columns: columns,
            alignment: .leading,
            spacing: gridSpacing
        ) {
            // All Categories Button
            CategoryChip(
                title: isGerman ? "Alle" : "All",
                icon: "list.bullet",
                isSelected: viewModel.selectedCategory == nil,
                action: {
                    viewModel.clearFilters()
                }
            )

            // Category Buttons
            ForEach(viewModel.categories) { category in
                CategoryChip(
                    title: category.title,
                    icon: category.icon,
                    isSelected: viewModel.selectedCategory?.id == category.id,
                    action: {
                        viewModel.selectCategory(category)
                    }
                )
            }
        }
    }

    // MARK: - Grid Columns

    private func adaptiveGridColumns() -> [GridItem] {
        // Always use 2 columns for consistent layout
        return Array(repeating: GridItem(.flexible(), spacing: ResponsiveDesign.spacing(12)), count: 2)
    }

    // MARK: - Category Based View

    private var categoryBasedView: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            if let selectedCategory = viewModel.selectedCategory {
                // Show FAQs for selected category
                categoryFAQsView(category: selectedCategory)
            } else {
                // Show all FAQs grouped by category
                ForEach(viewModel.categories) { category in
                    let faqs = viewModel.faqs(for: category)
                    if !faqs.isEmpty {
                        categoryFAQsView(category: category)
                    }
                }
            }
        }
    }

    // MARK: - Search Results View

    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            Text(isGerman ? "Suchergebnisse" : "Search Results")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text(
                isGerman
                ? "\(viewModel.filteredFAQs.count) Ergebnis\(viewModel.filteredFAQs.count == 1 ? "" : "se")"
                : "\(viewModel.filteredFAQs.count) result\(viewModel.filteredFAQs.count == 1 ? "" : "s") found"
            )
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                ForEach(viewModel.filteredFAQs) { faq in
                    FAQRow(faq: faq, isExpanded: viewModel.isExpanded(faq)) {
                        viewModel.toggleFAQ(faq)
                    }
                }
            }
        }
    }

    // MARK: - Category FAQs View

    private func categoryFAQsView(category: FAQCategoryContent) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: category.icon)
                    .foregroundColor(AppTheme.accentLightBlue)
                    .font(ResponsiveDesign.headlineFont())

                Text(category.title)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
            }

            let faqs = viewModel.faqs(for: category)
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                ForEach(faqs) { faq in
                    FAQRow(faq: faq, isExpanded: viewModel.isExpanded(faq)) {
                        viewModel.toggleFAQ(faq)
                    }
                }
            }
        }
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "magnifyingglass")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2.4))
                .foregroundColor(AppTheme.fontColor.opacity(0.5))

            Text(isGerman ? "Keine Ergebnisse" : "No Results Found")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text(isGerman ? "Bitte andere Suchbegriffe versuchen oder nach Kategorie stöbern." : "Try searching with different keywords or browse by category")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(ResponsiveDesign.spacing(32))
    }

    private var unavailableView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "wifi.slash")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2.4))
                .foregroundColor(AppTheme.fontColor.opacity(0.5))

            Text(isGerman ? "Help Center nicht verfügbar" : "Help Center Unavailable")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text(isGerman
                 ? "Die FAQs konnten gerade nicht geladen werden. Bitte versuche es später erneut."
                 : "FAQs could not be loaded right now. Please try again later.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)

            Button(action: {
                Task { await viewModel.reload() }
            }) {
                Text(isGerman ? "Erneut versuchen" : "Try Again")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.screenBackground)
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.vertical, ResponsiveDesign.spacing(10))
                    .background(AppTheme.accentLightBlue)
                    .cornerRadius(ResponsiveDesign.spacing(10))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(ResponsiveDesign.spacing(32))
    }
}

#Preview {
    HelpCenterView()
}
