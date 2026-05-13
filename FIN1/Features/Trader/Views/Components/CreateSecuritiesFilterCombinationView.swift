import SwiftUI

struct CreateSecuritiesFilterCombinationView: View {
    @ObservedObject var savedFiltersRepository: SavedSecuritiesFiltersRepository
    @Binding var currentFilters: SearchFilters
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateFilterCombinationViewModel

    init(savedFiltersRepository: SavedSecuritiesFiltersRepository, currentFilters: Binding<SearchFilters>) {
        self.savedFiltersRepository = savedFiltersRepository
        self._currentFilters = currentFilters
        self._viewModel = StateObject(wrappedValue: CreateFilterCombinationViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(6)) {
                    // Combination Name Input
                    FilterCombinationNameInput(viewModel: self.viewModel)

                    // Active Filters Preview
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                        Text("Active Filters (\(self.getFilterCount(self.currentFilters)))")
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.fontColor)

                        if self.getFilterCount(self.currentFilters) == 0 {
                            Text("No filters selected. Add filters from the main screen first.")
                                .foregroundColor(AppTheme.fontColor.opacity(0.6))
                                .padding()
                        } else {
                            LazyVStack(spacing: ResponsiveDesign.spacing(8)) {
                                FilterDetailRow(label: "Category", value: self.currentFilters.category)
                                FilterDetailRow(label: "Underlying Asset", value: self.currentFilters.underlyingAsset)
                                FilterDetailRow(label: "Direction", value: self.currentFilters.direction.rawValue)

                                if let strikePriceGap = currentFilters.strikePriceGap {
                                    FilterDetailRow(label: "Strike Price Gap", value: strikePriceGap)
                                }
                                if let remainingTerm = currentFilters.remainingTerm {
                                    FilterDetailRow(label: "Remaining Term", value: remainingTerm)
                                }
                                if let issuer = currentFilters.issuer {
                                    FilterDetailRow(label: "Issuer", value: issuer)
                                }
                                if let omega = currentFilters.omega {
                                    FilterDetailRow(label: "Omega", value: omega)
                                }
                            }
                            .padding(.horizontal, ResponsiveDesign.spacing(12))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            .background(AppTheme.inputFieldBackground)
                            .cornerRadius(ResponsiveDesign.spacing(8))
                        }
                    }

                    Spacer()

                    // Save Button
                    Button(action: self.saveCombination, label: {
                        Text("Save Combination")
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.screenBackground)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(self.canSave ? AppTheme.accentGreen : AppTheme.inputFieldBackground)
                            .cornerRadius(ResponsiveDesign.spacing(12))
                    })
                    .disabled(!self.canSave)

                    // Save button hint
                    if !self.canSave {
                        Text("Name must be 1-20 alphanumeric characters and have active filters")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, ResponsiveDesign.spacing(16))
                .padding(.top, ResponsiveDesign.spacing(16))
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Create Filter Combination")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { self.dismiss() }
                        .foregroundColor(AppTheme.accentRed)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { self.saveCombination() }
                        .foregroundColor(AppTheme.accentLightBlue)
                        .disabled(!self.canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        self.viewModel.canSave && self.getFilterCount(self.currentFilters) > 0
    }

    private func getFilterCount(_ filters: SearchFilters) -> Int {
        var count = 3 // category, underlyingAsset, direction are always present
        if filters.strikePriceGap != nil { count += 1 }
        if filters.remainingTerm != nil { count += 1 }
        if filters.issuer != nil { count += 1 }
        if filters.omega != nil { count += 1 }
        return count
    }

    private func saveCombination() {
        let trimmedName = self.viewModel.combinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newCombination = SecuritiesFilterCombination(name: trimmedName, filters: currentFilters)
        self.savedFiltersRepository.addFilter(newCombination)
        self.dismiss()
    }
}

#Preview {
    CreateSecuritiesFilterCombinationView(
        savedFiltersRepository: SavedSecuritiesFiltersRepository(),
        currentFilters: .constant(SearchFilters(
            category: "Warrant",
            underlyingAsset: "DAX",
            direction: .call,
            strikePriceGap: "At the Money",
            remainingTerm: nil,
            issuer: nil,
            omega: nil
        ))
    )
}
