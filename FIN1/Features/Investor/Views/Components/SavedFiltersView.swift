import SwiftUI

struct SavedFiltersView: View {
    @ObservedObject var savedFiltersManager: SavedFiltersManager
    @Environment(\.dismiss) private var dismiss
    let onActivateFilter: (FilterCombination) -> Void
    let currentlyAppliedFilterID: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        // Help text
                        Text("Tap 'Activate' on any filter combination to apply it to your current search. The activated filter will be highlighted in green.")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                            .padding(.vertical, ResponsiveDesign.spacing(12))
                            .background(AppTheme.inputFieldBackground)
                            .cornerRadius(ResponsiveDesign.spacing(8))

                        if savedFiltersManager.savedFilters.isEmpty {
                            VStack(spacing: ResponsiveDesign.spacing(16)) {
                                Image(systemName: "tray")
                                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2.0))
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
                                ForEach(savedFiltersManager.savedFilters) { savedFilter in
                                    SavedFilterRow(
                                        savedFilter: savedFilter,
                                        onDelete: { savedFiltersManager.removeFilter(savedFilter) },
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

// MARK: - Saved Filter Row
struct SavedFilterRow: View {
    let savedFilter: FilterCombination
    let onDelete: () -> Void
    let onActivate: () -> Void
    let isCurrentlyApplied: Bool
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    Text(savedFilter.name)
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    if isCurrentlyApplied {
                        Image(systemName: "checkmark.circle.fill")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentGreen)
                    }
                }

                Spacer()

                if savedFilter.isDefault {
                    Text("Default")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.screenBackground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.buttonColor)
                        .cornerRadius(ResponsiveDesign.spacing(6))
                }

                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    if isCurrentlyApplied {
                        Text("Currently Applied")
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.accentGreen)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.accentGreen.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(6))
                                    .stroke(AppTheme.accentGreen, lineWidth: 1)
                            )
                            .cornerRadius(ResponsiveDesign.spacing(6))
                    } else {
                        Button(action: onActivate, label: {
                            Text("Activate")
                                .font(ResponsiveDesign.captionFont())
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.screenBackground)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppTheme.buttonColor)
                                .cornerRadius(ResponsiveDesign.spacing(6))
                        })
                    }

                    Button(action: { showDeleteConfirmation = true }, label: {
                        Image(systemName: "trash")
                            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                            .foregroundColor(AppTheme.accentRed)
                            .frame(width: ResponsiveDesign.iconSize() * 1.5, height: ResponsiveDesign.iconSize() * 1.5)
                            .background(AppTheme.accentRed.opacity(0.1))
                            .clipShape(Circle())
                    })
                    .accessibilityLabel("Delete filter combination")
                    .accessibilityHint("Deletes the saved filter combination")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(savedFilter.filters, id: \.type) { filter in
                    HStack {
                        Text("•")
                            .foregroundColor(AppTheme.accentLightBlue)

                        Text("\(filter.type.displayName): \(filter.selectedOption.displayName)")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)

                        Spacer()
                    }
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
    SavedFiltersView(
        savedFiltersManager: SavedFiltersManager(),
        onActivateFilter: { _ in },
        currentlyAppliedFilterID: nil
    )
}
