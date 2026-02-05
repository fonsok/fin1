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
                        SearchHeaderView(searchText: $viewModel.wknIsin)
                            .accessibilityIdentifier("SecuritiesSearchHeader")

                        Divider().background(Color.gray)

                        // Derivatives Search Form (with Saved Filters Section integrated)
                        SearchFormSection(
                            category: $viewModel.category,
                            underlyingAsset: $viewModel.underlyingAsset,
                            direction: $viewModel.direction,
                            activeSheet: $viewModel.activeSheet,
                            onBasiswertTap: { viewModel.activeSheet = .underlyingAsset },
                            onCategoryTap: { viewModel.activeSheet = .category },
                            savedFiltersContent: {
                                AnyView(
                                    SavedSecuritiesFiltersSection(
                                        savedFilters: savedFiltersRepository.savedFilters,
                                        hasActiveFilters: viewModel.hasActiveFilters(),
                                        onViewAll: { showSavedFilters = true },
                                        onCreateNew: { showCreateCombination = true },
                                        onApplyFilter: { savedFilter in
                                            viewModel.applySavedFilter(savedFilter)
                                        },
                                        currentlyAppliedFilterID: viewModel.getAppliedFilterID()
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
                            strikePriceGap: $viewModel.strikePriceGap,
                            remainingTerm: $viewModel.remainingTerm,
                            issuer: $viewModel.issuer,
                            omega: $viewModel.omega,
                            activeSheet: $viewModel.activeSheet,
                            warrantDetailsViewModel: warrantDetailsViewModel
                        )

                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(AppTheme.systemSeparator)
                            .padding(.vertical, ResponsiveDesign.spacing(8))

                        // Selected Filters Display
                        ChipFlowLayout(
                            strikePriceGap: $viewModel.strikePriceGap,
                            remainingTerm: $viewModel.remainingTerm,
                            issuer: $viewModel.issuer
                        )

                        // Search Results
                        SearchResultView(
                            results: viewModel.searchResults,
                            filterType: viewModel.direction.rawValue,
                            filterDescription: viewModel.getFilterDescription(),
                            warrantDetailsViewModel: warrantDetailsViewModel
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
                viewModel.setSavedFiltersToCheck(savedFiltersRepository.savedFilters)
                viewModel.performSearch()

                // Register repository with FilterSyncService
                if let filterSyncService = services.filterSyncService as? FilterSyncService {
                    filterSyncService.registerSecuritiesFiltersRepository(savedFiltersRepository)
                }
            }
            .onChange(of: savedFiltersRepository.savedFilters) { _, newFilters in
                viewModel.setSavedFiltersToCheck(newFilters)
            }
            .onReceive(NotificationCenter.default.publisher(for: .orderPlacedSuccessfully)) { _ in
                // Dismiss the entire securities search view when order is placed successfully
                dismiss()
            }
            .navigationBarTitle("Wertpapiersuche", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Wertpapiersuche")
                        .foregroundColor(AppTheme.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSavedFilters) {
                SavedSecuritiesFiltersView(
                    savedFiltersRepository: savedFiltersRepository,
                    onActivateFilter: { savedFilter in
                        viewModel.applySavedFilter(savedFilter)
                        showSavedFilters = false
                    },
                    currentlyAppliedFilterID: viewModel.getAppliedFilterID()
                )
            }
            .sheet(isPresented: $showCreateCombination) {
                CreateSecuritiesFilterCombinationView(
                    savedFiltersRepository: savedFiltersRepository,
                    currentFilters: Binding(
                        get: { viewModel.getCurrentFilters() },
                        set: { _ in }
                    )
                )
            }
            .sheet(item: $viewModel.activeSheet) { sheet in
                switch sheet {
                case .category:
                    DerivateCategoryListView(selectedCategory: $viewModel.category)
                case .underlyingAsset:
                    UnderlyingAssetListView(selectedUnderlying: $viewModel.underlyingAsset)
                case .strikePriceGap:
                    StrikePriceGapView(selectedGap: $viewModel.strikePriceGap)
                case .remainingTerm:
                    RemainingTermView(selectedLaufzeit: $viewModel.remainingTerm)
                case .issuer:
                    EmittentListView(selectedEmittent: $viewModel.issuer)
                case .omega:
                    OmegaFilterView(selectedOmega: $viewModel.omega)
                }
            }
        }
    }
}

#Preview {
    SecuritiesSearchView(services: .live)
}
