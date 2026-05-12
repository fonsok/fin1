import SwiftUI

struct SavedFiltersSection: View {
    let savedFilters: [FilterCombination]
    let activeFilters: [IndividualFilterCriteria]
    let onViewAll: () -> Void
    let onCreateNew: () -> Void
    let onApplyFilter: (FilterCombination) -> Void
    let onDeleteFilter: (FilterCombination) -> Void
    let currentlyAppliedFilterID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Save(d) Filter Combination(s)")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                Button("View All") {
                    onViewAll()
                }
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.accentLightBlue)
            }

            // Display saved filters in a 2-column grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: ResponsiveDesign.spacing(8)),
                GridItem(.flexible(), spacing: ResponsiveDesign.spacing(8))
            ], spacing: ResponsiveDesign.spacing(8)) {
                ForEach(savedFilters) { savedFilter in
                    SavedFilterChip(
                        savedFilter: savedFilter,
                        onApply: { onApplyFilter(savedFilter) },
                        onDelete: { onDeleteFilter(savedFilter) },
                        isCurrentlyApplied: currentlyAppliedFilterID == savedFilter.id.uuidString
                    )
                }

                // Only show "Save" button if there are active filters and no saved filter is currently applied
                if !activeFilters.isEmpty && currentlyAppliedFilterID == nil {
                    Button(action: onCreateNew, label: {
                        VStack(spacing: ResponsiveDesign.spacing(4)) {
                            Image(systemName: "plus")
                                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                            Text("Save")
                                .font(ResponsiveDesign.bodyFont())
                        }
                        .foregroundColor(AppTheme.accentGreen.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, ResponsiveDesign.spacing(12))
                        .padding(.vertical, ResponsiveDesign.spacing(8))
                        .background(AppTheme.inputFieldBackground.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                                .stroke(AppTheme.accentLightBlue, lineWidth: 1)
                        )
                        .cornerRadius(ResponsiveDesign.spacing(8))
                    })
                }
            }
        }
    }
}

// MARK: - Saved Filter Chip Component
struct SavedFilterChip: View {
    let savedFilter: FilterCombination
    let onApply: () -> Void
    let onDelete: () -> Void
    let isCurrentlyApplied: Bool

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: onApply, label: {
                HStack(alignment: .top, spacing: ResponsiveDesign.spacing(4)) {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                        Text(savedFilter.name)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(isCurrentlyApplied ? .white : AppTheme.inputFieldText)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)

                        Text("\(savedFilter.filters.count) filters")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(isCurrentlyApplied ? .white : AppTheme.inputFieldText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isCurrentlyApplied {
                        Image(systemName: "checkmark.circle.fill")
                            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.7))
                            .foregroundColor(AppTheme.accentGreen)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ResponsiveDesign.spacing(12))
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .background(isCurrentlyApplied ? AppTheme.accentGreen.opacity(0.1) : AppTheme.inputFieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                        .stroke(isCurrentlyApplied ? AppTheme.accentGreen : AppTheme.accentLightBlue, lineWidth: 1)
                )
                .cornerRadius(ResponsiveDesign.spacing(8))
            })
            .buttonStyle(PlainButtonStyle())

            // Delete button (X) positioned at center-right
            Button(action: { showDeleteConfirmation = true }, label: {
                Image(systemName: "xmark")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.7))
                    .foregroundColor(AppTheme.accentRed.opacity(0.8))
            })
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, ResponsiveDesign.spacing(4))
        }
        .opacity(0.7)
        .alert("Delete Filter Combination", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \"\(savedFilter.name)\"? This action cannot be undone.")
        }
    }
}

#Preview {
    SavedFiltersSection(
        savedFilters: [
            FilterCombination(name: "High Performers", filters: [], isDefault: false),
            FilterCombination(name: "Conservative", filters: [], isDefault: true)
        ],
        activeFilters: [],
        onViewAll: {},
        onCreateNew: {},
        onApplyFilter: { _ in },
        onDeleteFilter: { _ in },
        currentlyAppliedFilterID: nil
    )
    .padding()
    .background(AppTheme.screenBackground)
}
