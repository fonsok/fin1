import SwiftUI

struct CreateFilterCombinationView: View {
    @ObservedObject var savedFiltersManager: SavedFiltersManager
    @Binding var activeFilters: [IndividualFilterCriteria]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateFilterCombinationViewModel

    init(savedFiltersManager: SavedFiltersManager, activeFilters: Binding<[IndividualFilterCriteria]>) {
        self.savedFiltersManager = savedFiltersManager
        self._activeFilters = activeFilters
        self._viewModel = StateObject(wrappedValue: CreateFilterCombinationViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(24)) {
                    // Combination Name Input
                    FilterCombinationNameInput(viewModel: viewModel)

                    // Active Filters Preview
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                        Text("Active Filters (\(activeFilters.count))")
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.fontColor)

                        if activeFilters.isEmpty {
                            Text("No filters selected. Add filters from the main screen first.")
                                .foregroundColor(AppTheme.fontColor.opacity(0.6))
                                .padding()
                        } else {
                            // Display chips in a 2-column grid matching Active Filters style
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: ResponsiveDesign.spacing(8)),
                                GridItem(.flexible(), spacing: ResponsiveDesign.spacing(8))
                            ], spacing: ResponsiveDesign.spacing(8)) {
                                ForEach(activeFilters, id: \.type) { filter in
                                    FilterPreviewChip(filter: filter, displayValue: displayValue(for: filter))
                                }
                            }
                        }
                    }

                    Spacer()

                    // Save Button
                    Button(action: saveCombination, label: {
                        Text("Save Combination")
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.screenBackground)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSave ? AppTheme.accentGreen : AppTheme.inputFieldBackground)
                            .cornerRadius(ResponsiveDesign.spacing(12))
                    })
                    .disabled(!canSave)

                    // Save button hint
                    if !canSave {
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
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.accentRed)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveCombination() }
                        .foregroundColor(AppTheme.accentLightBlue)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        viewModel.canSave && !activeFilters.isEmpty
    }

    private func saveCombination() {
        let trimmedName = viewModel.combinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newCombination = FilterCombination(name: trimmedName, filters: activeFilters)
        savedFiltersManager.addFilter(newCombination)
        dismiss()
    }

    // Helper function to get display value for each filter type
    private func displayValue(for filter: IndividualFilterCriteria) -> String {
        switch filter.type {
        case .returnRate:
            return filter.returnPercentageOption?.displayName ?? "---"
        case .numberOfTrades:
            return filter.numberOfTradesOption?.displayName ?? "---"
        case .recentSuccessfulTrades, .highestReturn, .timeRange:
            return filter.successRateOption?.displayName ?? "---"
        }
    }
}

// MARK: - Filter Preview Chip Component (matches ActiveFilterChip style without remove button)
private struct FilterPreviewChip: View {
    let filter: IndividualFilterCriteria
    let displayValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
            // Label - smaller font, less opacity, allows line breaks
            Text(filter.type.displayName)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            // Value - normal font, normal opacity, allows line breaks
            Text(displayValue)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ResponsiveDesign.spacing(8))
        .padding(.vertical, ResponsiveDesign.spacing(6))
        .background(AppTheme.accentLightBlue.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                .stroke(AppTheme.accentLightBlue, lineWidth: 1)
        )
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

#Preview {
    CreateFilterCombinationView(
        savedFiltersManager: SavedFiltersManager(),
        activeFilters: .constant([
            IndividualFilterCriteria(type: .returnRate, selectedOption: .atLeast8OutOf10)
        ])
    )
}
