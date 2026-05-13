import SwiftUI

struct SavedSecuritiesFiltersSection: View {
    let savedFilters: [SecuritiesFilterCombination]
    let hasActiveFilters: Bool
    let onViewAll: () -> Void
    let onCreateNew: () -> Void
    let onApplyFilter: (SecuritiesFilterCombination) -> Void
    let currentlyAppliedFilterID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Save(d) Filter Combination(s)")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Button("View All") {
                    self.onViewAll()
                }
                .foregroundColor(AppTheme.accentLightBlue)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    ForEach(self.savedFilters.prefix(3)) { savedFilter in
                        SavedSecuritiesFilterChip(
                            savedFilter: savedFilter,
                            onApply: { self.onApplyFilter(savedFilter) },
                            isCurrentlyApplied: self.currentlyAppliedFilterID == savedFilter.id.uuidString
                        )
                    }

                    // Only show "Save" button if there are active filters
                    if self.hasActiveFilters {
                        Button(action: self.onCreateNew, label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Save")
                            }
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                            .padding(.horizontal, ResponsiveDesign.spacing(12))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            .background(AppTheme.inputFieldBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                                    .stroke(AppTheme.accentLightBlue, lineWidth: 1)
                            )
                            .cornerRadius(ResponsiveDesign.spacing(8))
                        })
                    }
                }
                .padding(.horizontal, ResponsiveDesign.spacing(4))
            }
        }
    }
}

// MARK: - Saved Securities Filter Chip Component
struct SavedSecuritiesFilterChip: View {
    let savedFilter: SecuritiesFilterCombination
    let onApply: () -> Void
    let isCurrentlyApplied: Bool

    var body: some View {
        Button(action: self.onApply, label: {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                HStack {
                    Text(self.savedFilter.name)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.inputFieldText)

                    if self.isCurrentlyApplied {
                        Image(systemName: "checkmark")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                    }
                }

                Text("\(self.getFilterCount(self.savedFilter.filters)) filters")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.inputFieldText.opacity(0.7))
            }
            .frame(width: 120, alignment: .leading)
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .background(self.isCurrentlyApplied ? AppTheme.accentOrange.opacity(0.7) : AppTheme.inputFieldBackground)
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                    .stroke(self.isCurrentlyApplied ? AppTheme.accentLightBlue : AppTheme.accentLightBlue, lineWidth: 1)
            )
            .cornerRadius(ResponsiveDesign.spacing(8))
        })
    }

    private func getFilterCount(_ filters: SearchFilters) -> Int {
        var count = 3 // category, underlyingAsset, direction are always present
        if filters.strikePriceGap != nil { count += 1 }
        if filters.remainingTerm != nil { count += 1 }
        if filters.issuer != nil { count += 1 }
        if filters.omega != nil { count += 1 }
        return count
    }
}

#Preview {
    SavedSecuritiesFiltersSection(
        savedFilters: [],
        hasActiveFilters: true,
        onViewAll: {},
        onCreateNew: {},
        onApplyFilter: { _ in },
        currentlyAppliedFilterID: nil
    )
    .padding()
    .background(AppTheme.screenBackground)
}
