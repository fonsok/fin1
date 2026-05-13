import SwiftUI

struct SecuritiesSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var services
    @StateObject private var viewModel: SecuritiesSearchViewModel
    @StateObject private var warrantDetailsViewModel: WarrantDetailsViewModel
    @StateObject private var savedFiltersRepository: SavedSecuritiesFiltersRepository
    @State private var showSavedFilters = false
    @State private var showCreateCombination = false
    @Environment(\.themeManager) private var themeManager

    init(services: AppServices) {
        _viewModel = StateObject(wrappedValue: SecuritiesSearchViewModel(coordinator: services.securitiesSearchCoordinator))
        _warrantDetailsViewModel = StateObject(wrappedValue: WarrantDetailsViewModel())
        _savedFiltersRepository = StateObject(wrappedValue: SavedSecuritiesFiltersRepository())
    }

    enum Direction: String, CaseIterable {
        case call = "Call"
        case put = "Put"
    }

    enum ActiveSheet: Identifiable {
        case category, underlyingAsset, strikePriceGap, remainingTerm, issuer, omega
        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
                        // Search Bar
                        SearchHeaderView(searchText: self.$viewModel.wknIsin)
                            .accessibilityIdentifier("SecuritiesSearchHeader")

                        Divider().background(Color.gray)

                        // Derivatives Search Form (with Saved Filters Section integrated)
                        SearchFormSection(
                            category: self.$viewModel.category,
                            underlyingAsset: self.$viewModel.underlyingAsset,
                            direction: self.$viewModel.direction,
                            activeSheet: self.$viewModel.activeSheet,
                            onBasiswertTap: { self.viewModel.activeSheet = .underlyingAsset },
                            onCategoryTap: { self.viewModel.activeSheet = .category },
                            savedFiltersContent: {
                                AnyView(
                                    SavedSecuritiesFiltersSection(
                                        savedFilters: self.savedFiltersRepository.savedFilters,
                                        hasActiveFilters: self.viewModel.hasActiveFilters(),
                                        onViewAll: { self.showSavedFilters = true },
                                        onCreateNew: { self.showCreateCombination = true },
                                        onApplyFilter: { savedFilter in
                                            self.viewModel.applySavedFilter(savedFilter)
                                        },
                                        currentlyAppliedFilterID: self.viewModel.getAppliedFilterID()
                                    )
                                )
                            }
                        )

                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(AppTheme.systemSeparator)
                            .padding(.vertical, ResponsiveDesign.spacing(8))

                        // Dynamic Filter Section
                        FilterSection(
                            strikePriceGap: self.$viewModel.strikePriceGap,
                            remainingTerm: self.$viewModel.remainingTerm,
                            issuer: self.$viewModel.issuer,
                            omega: self.$viewModel.omega,
                            activeSheet: self.$viewModel.activeSheet,
                            warrantDetailsViewModel: self.warrantDetailsViewModel
                        )

                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(AppTheme.systemSeparator)
                            .padding(.vertical, ResponsiveDesign.spacing(8))

                        // Selected Filters Display
                        ChipFlowLayout(
                            strikePriceGap: self.$viewModel.strikePriceGap,
                            remainingTerm: self.$viewModel.remainingTerm,
                            issuer: self.$viewModel.issuer
                        )

                        // Search Results
                        SearchResultView(
                            results: self.viewModel.searchResults,
                            filterType: self.viewModel.direction.rawValue,
                            filterDescription: self.viewModel.getFilterDescription(),
                            warrantDetailsViewModel: self.warrantDetailsViewModel
                        )
                        .padding(.top, ResponsiveDesign.spacing(16))
                    }
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.top, ResponsiveDesign.spacing(8))
                }
            }
            .dismissKeyboardOnTap()
            .onAppear {
                print("🔍 DEBUG: SecuritiesSearchView onAppear called")
                self.viewModel.setSavedFiltersToCheck(self.savedFiltersRepository.savedFilters)
                self.viewModel.performSearch()

                // Register repository with FilterSyncService
                if let filterSyncService = services.filterSyncService as? FilterSyncService {
                    filterSyncService.registerSecuritiesFiltersRepository(self.savedFiltersRepository)
                }
            }
            .onChange(of: self.savedFiltersRepository.savedFilters) { _, newFilters in
                self.viewModel.setSavedFiltersToCheck(newFilters)
            }
            .onReceive(NotificationCenter.default.publisher(for: .orderPlacedSuccessfully)) { _ in
                // Dismiss the entire securities search view when order is placed successfully
                self.dismiss()
            }
            .navigationBarTitle("Wertpapiersuche", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Wertpapiersuche")
                        .foregroundColor(AppTheme.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        self.dismiss()
                    }
                }
            }
            .sheet(isPresented: self.$showSavedFilters) {
                SavedSecuritiesFiltersView(
                    savedFiltersRepository: self.savedFiltersRepository,
                    onActivateFilter: { savedFilter in
                        self.viewModel.applySavedFilter(savedFilter)
                        self.showSavedFilters = false
                    },
                    currentlyAppliedFilterID: self.viewModel.getAppliedFilterID()
                )
            }
            .sheet(isPresented: self.$showCreateCombination) {
                CreateSecuritiesFilterCombinationView(
                    savedFiltersRepository: self.savedFiltersRepository,
                    currentFilters: Binding(
                        get: { self.viewModel.getCurrentFilters() },
                        set: { _ in }
                    )
                )
            }
            .sheet(item: self.$viewModel.activeSheet) { sheet in
                switch sheet {
                case .category:
                    DerivateCategoryListView(selectedCategory: self.$viewModel.category)
                case .underlyingAsset:
                    UnderlyingAssetListView(selectedUnderlying: self.$viewModel.underlyingAsset)
                case .strikePriceGap:
                    StrikePriceGapView(selectedGap: self.$viewModel.strikePriceGap)
                case .remainingTerm:
                    RemainingTermView(selectedLaufzeit: self.$viewModel.remainingTerm)
                case .issuer:
                    EmittentListView(selectedEmittent: self.$viewModel.issuer)
                case .omega:
                    OmegaFilterView(selectedOmega: self.$viewModel.omega)
                }
            }
        }
    }
}

#Preview {
    SecuritiesSearchView(services: .live)
}
