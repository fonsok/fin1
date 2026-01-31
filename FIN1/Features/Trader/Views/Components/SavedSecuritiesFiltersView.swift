import SwiftUI

struct SavedSecuritiesFiltersView: View {
    @ObservedObject var savedFiltersRepository: SavedSecuritiesFiltersRepository
    @Environment(\.dismiss) private var dismiss
    let onActivateFilter: (SecuritiesFilterCombination) -> Void
    let currentlyAppliedFilterID: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        // Help text
                        Text("Tap 'Activate' on any filter combination to apply it to your current search. The activated filter will be highlighted in orange.")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.inputFieldText.opacity(0.7))
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                            .padding(.vertical, ResponsiveDesign.spacing(12))
                            .background(AppTheme.inputFieldBackground)
                            .cornerRadius(ResponsiveDesign.spacing(8))

                        if savedFiltersRepository.savedFilters.isEmpty {
                            VStack(spacing: ResponsiveDesign.spacing(16)) {
                                Image(systemName: "tray")
                                    .font(.system(size: ResponsiveDesign.iconSize() * 2.0))
                                    .foregroundColor(AppTheme.fontColor.opacity(0.3))

                                Text("No saved filter combinations yet")
                                    .font(ResponsiveDesign.headlineFont())
                                    .foregroundColor(AppTheme.fontColor)

                                Text("Create your first filter combination from the main screen")
                                    .font(ResponsiveDesign.bodyFont())
                                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            }
                            .padding(.vertical, ResponsiveDesign.spacing(40))
                        } else {
                            LazyVStack(spacing: ResponsiveDesign.spacing(16)) {
                                ForEach(savedFiltersRepository.savedFilters) { savedFilter in
                                    SavedSecuritiesFilterRow(
                                        savedFilter: savedFilter,
                                        onDelete: { savedFiltersRepository.removeFilter(savedFilter) },
                                        onActivate: { onActivateFilter(savedFilter) },
                                        isCurrentlyApplied: currentlyAppliedFilterID == savedFilter.id.uuidString
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.top, ResponsiveDesign.spacing(16))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Saved Filters")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }
}

// MARK: - Saved Securities Filter Row
struct SavedSecuritiesFilterRow: View {
    let savedFilter: SecuritiesFilterCombination
    let onDelete: () -> Void
    let onActivate: () -> Void
    let isCurrentlyApplied: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    Text(savedFilter.name)
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    if isCurrentlyApplied {
                        Image(systemName: "checkmark")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentOrange)
                    }
                }

                Spacer()

                if savedFilter.isDefault {
                    Text("Default")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.screenBackground)
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                        .background(AppTheme.buttonColor)
                        .cornerRadius(ResponsiveDesign.spacing(6))
                }

                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    if isCurrentlyApplied {
                        Text("Currently Applied")
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.accentOrange)
                            .padding(.horizontal, ResponsiveDesign.spacing(12))
                            .padding(.vertical, ResponsiveDesign.spacing(6))
                            .background(AppTheme.accentOrange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(6))
                                    .stroke(AppTheme.accentOrange, lineWidth: 1)
                            )
                            .cornerRadius(ResponsiveDesign.spacing(6))
                    } else {
                        Button(action: onActivate, label: {
                            Text("Activate")
                                .font(ResponsiveDesign.captionFont())
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.screenBackground)
                                .padding(.horizontal, ResponsiveDesign.spacing(12))
                                .padding(.vertical, ResponsiveDesign.spacing(6))
                                .background(AppTheme.accentOrange.opacity(0.7))
                                .cornerRadius(ResponsiveDesign.spacing(6))
                        })
                    }

                    Button(action: onDelete, label: {
                        Image(systemName: "trash")
                            .foregroundColor(AppTheme.accentRed.opacity(0.6))
                    })
                }
            }

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                FilterDetailRow(label: "Category", value: savedFilter.filters.category)
                FilterDetailRow(label: "Underlying Asset", value: savedFilter.filters.underlyingAsset)
                FilterDetailRow(label: "Direction", value: savedFilter.filters.direction.rawValue)

                if let strikePriceGap = savedFilter.filters.strikePriceGap {
                    FilterDetailRow(label: "Strike Price Gap", value: strikePriceGap)
                }
                if let remainingTerm = savedFilter.filters.remainingTerm {
                    FilterDetailRow(label: "Remaining Term", value: remainingTerm)
                }
                if let issuer = savedFilter.filters.issuer {
                    FilterDetailRow(label: "Issuer", value: issuer)
                }
                if let omega = savedFilter.filters.omega {
                    FilterDetailRow(label: "Omega", value: omega)
                }
            }

            Text("Created: \(savedFilter.createdAt, style: .date)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(isCurrentlyApplied ? AppTheme.accentGreen.opacity(0.05) : AppTheme.sectionBackground)
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .stroke(isCurrentlyApplied ? AppTheme.accentGreen.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Filter Detail Row
struct FilterDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text("•")
                .foregroundColor(AppTheme.accentLightBlue)

            Text("\(label): ")
                .font(ResponsiveDesign.bodyFont())
            //    .foregroundColor(AppTheme.fontColor)
                .foregroundColor(.white.opacity(0.7))

            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            Spacer()
        }
    }
}

#Preview {
    SavedSecuritiesFiltersView(
        savedFiltersRepository: SavedSecuritiesFiltersRepository(),
        onActivateFilter: { _ in },
        currentlyAppliedFilterID: nil
    )
}
