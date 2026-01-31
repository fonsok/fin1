import SwiftUI

struct ActiveFiltersSection: View {
    let activeFilters: [IndividualFilterCriteria]
    let currentlyAppliedFilterID: String?
    let currentFilterName: String?
    let onClearAll: () -> Void
    let onRemoveFilter: (IndividualFilterCriteria.FilterType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            // Header
            HStack {
                Text("Active Filters (\(activeFilters.count))")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.thin)
                    .foregroundColor(AppTheme.fontColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                if !activeFilters.isEmpty {
                    Button("Clear All") {
                        onClearAll()
                    }
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.accentRed)
                }
            }

            // Display chips in a 2-column grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: ResponsiveDesign.spacing(8)),
                GridItem(.flexible(), spacing: ResponsiveDesign.spacing(8))
            ], spacing: ResponsiveDesign.spacing(8)) {
                ForEach(activeFilters, id: \.type) { filter in
                    ActiveFilterChip(filter: filter) {
                        onRemoveFilter(filter.type)
                    }
                }
            }
        }
    }
}

// MARK: - Active Filter Chip Component
struct ActiveFilterChip: View {
    let filter: IndividualFilterCriteria
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: ResponsiveDesign.spacing(6)) {
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

            Button(action: onRemove, label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: ResponsiveDesign.iconSize() * 0.7))
                    .foregroundColor(AppTheme.accentRed.opacity(0.8))
            })
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, ResponsiveDesign.spacing(8))
        .padding(.vertical, ResponsiveDesign.spacing(6))
        .background(AppTheme.accentLightBlue.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                .stroke(AppTheme.accentLightBlue, lineWidth: 1)
        )
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    // Use displayName for all filter options (English)
    // Handle different filter types with their specific option types
    private var displayValue: String {
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

#Preview {
    ActiveFiltersSection(
        activeFilters: [
            IndividualFilterCriteria(type: .returnRate, returnPercentageOption: .greaterThan80),
            IndividualFilterCriteria(type: .recentSuccessfulTrades, successRateOption: .atLeast16OutOf20)
        ],
        currentlyAppliedFilterID: nil,
        currentFilterName: nil,
        onClearAll: {},
        onRemoveFilter: { _ in }
    )
    .padding()
    .background(AppTheme.screenBackground)
}
