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
                        self.searchSection

                        // Category Filter
                        if !self.viewModel.categories.isEmpty {
                            self.categoryFilterSection
                        }

                        // Content
                        if self.viewModel.isLoading {
                            ProgressView()
                                .tint(AppTheme.accentLightBlue)
                                .padding(.top, ResponsiveDesign.spacing(24))
                        } else if self.viewModel.hasNoFAQs {
                            self.unavailableView
                        } else if self.viewModel.hasNoSearchResults {
                            self.noResultsView
                        } else if !self.viewModel.searchQuery.isEmpty {
                            self.searchResultsView
                        } else {
                            self.categoryBasedView
                        }
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.top, ResponsiveDesign.spacing(16))
                    .padding(.bottom, ResponsiveDesign.spacing(24))
                }
                .refreshable {
                    await self.viewModel.reload()
                }
            }
            .navigationTitle(self.isGerman ? "Hilfe" : "Help Center")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(self.isGerman ? "Fertig" : "Done") {
                        self.dismiss()
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

            TextField(self.isGerman ? "FAQs durchsuchen..." : "Search FAQs...", text: self.$viewModel.searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(AppTheme.fontColor)
                .onChange(of: self.viewModel.searchQuery) { _, newValue in
                    // Clear category selection when searching
                    if !newValue.isEmpty {
                        self.viewModel.selectCategory(nil)
                    }
                }

            if !self.viewModel.searchQuery.isEmpty {
                Button(action: {
                    self.viewModel.searchQuery = ""
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
        let columns = self.adaptiveGridColumns()
        let gridSpacing = ResponsiveDesign.spacing(12)

        return LazyVGrid(
            columns: columns,
            alignment: .leading,
            spacing: gridSpacing
        ) {
            // All Categories Button
            CategoryChip(
                title: self.isGerman ? "Alle" : "All",
                icon: "list.bullet",
                isSelected: self.viewModel.selectedCategory == nil,
                action: {
                    self.viewModel.clearFilters()
                }
            )

            // Category Buttons
            ForEach(self.viewModel.categories) { category in
                CategoryChip(
                    title: category.title,
                    icon: category.icon,
                    isSelected: self.viewModel.selectedCategory?.id == category.id,
                    action: {
                        self.viewModel.selectCategory(category)
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
                self.categoryFAQsView(category: selectedCategory)
            } else {
                // Show all FAQs grouped by category
                ForEach(self.viewModel.categories) { category in
                    let faqs = self.viewModel.faqs(for: category)
                    if !faqs.isEmpty {
                        self.categoryFAQsView(category: category)
                    }
                }
            }
        }
    }

    // MARK: - Search Results View

    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            Text(self.isGerman ? "Suchergebnisse" : "Search Results")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text(
                self.isGerman
                    ? "\(self.viewModel.filteredFAQs.count) Ergebnis\(self.viewModel.filteredFAQs.count == 1 ? "" : "se")"
                    : "\(self.viewModel.filteredFAQs.count) result\(self.viewModel.filteredFAQs.count == 1 ? "" : "s") found"
            )
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.7))

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                ForEach(self.viewModel.filteredFAQs) { faq in
                    FAQRow(faq: faq, isExpanded: self.viewModel.isExpanded(faq)) {
                        self.viewModel.toggleFAQ(faq)
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

            let faqs = self.viewModel.faqs(for: category)
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                ForEach(faqs) { faq in
                    FAQRow(faq: faq, isExpanded: self.viewModel.isExpanded(faq)) {
                        self.viewModel.toggleFAQ(faq)
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

            Text(self.isGerman ? "Keine Ergebnisse" : "No Results Found")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text(
                self.isGerman ? "Bitte andere Suchbegriffe versuchen oder nach Kategorie stöbern." : "Try searching with different keywords or browse by category"
            )
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

            Text(self.isGerman ? "Help Center nicht verfügbar" : "Help Center Unavailable")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text(self.isGerman
                ? "Die FAQs konnten gerade nicht geladen werden. Bitte versuche es später erneut."
                : "FAQs could not be loaded right now. Please try again later.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)

            Button(action: {
                Task { await self.viewModel.reload() }
            }) {
                Text(self.isGerman ? "Erneut versuchen" : "Try Again")
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
