import SwiftUI

// MARK: - Ticket Tag Picker

/// Component for selecting and managing ticket tags
struct TicketTagPicker: View {
    @Binding var selectedTags: [TicketTag]
    let availableTags: [TicketTag]
    let maxTags: Int

    @State private var searchQuery = ""
    @Environment(\.dismiss) private var dismiss

    init(
        selectedTags: Binding<[TicketTag]>,
        availableTags: [TicketTag] = TicketTag.defaults,
        maxTags: Int = 5
    ) {
        self._selectedTags = selectedTags
        self.availableTags = availableTags
        self.maxTags = maxTags
    }

    private var filteredTags: [TicketTag] {
        if searchQuery.isEmpty {
            return availableTags
        }
        return availableTags.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selected tags
                if !selectedTags.isEmpty {
                    selectedTagsSection
                }

                // Search
                searchBar

                // Available tags
                tagList
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Tags auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: - Selected Tags Section

    private var selectedTagsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Ausgewählt (\(selectedTags.count)/\(maxTags))")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Spacer()

                if !selectedTags.isEmpty {
                    Button("Alle entfernen") {
                        selectedTags.removeAll()
                    }
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentRed)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(selectedTags) { tag in
                        SelectedTagChip(tag: tag) {
                            selectedTags.removeAll { $0.id == tag.id }
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.fontColor.opacity(0.5))

            TextField("Tag suchen...", text: $searchQuery)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
    }

    // MARK: - Tag List

    private var tagList: some View {
        ScrollView {
            LazyVStack(spacing: ResponsiveDesign.spacing(8)) {
                ForEach(filteredTags) { tag in
                    TagSelectionRow(
                        tag: tag,
                        isSelected: selectedTags.contains { $0.id == tag.id },
                        isDisabled: selectedTags.count >= maxTags && !selectedTags.contains { $0.id == tag.id }
                    ) {
                        toggleTag(tag)
                    }
                }

                if filteredTags.isEmpty {
                    Text("Keine Tags gefunden")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .padding()
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func toggleTag(_ tag: TicketTag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
        } else if selectedTags.count < maxTags {
            selectedTags.append(tag)
        }
    }
}

// MARK: - Selected Tag Chip

private struct SelectedTagChip: View {
    let tag: TicketTag
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(4)) {
            if let icon = tag.icon {
                Image(systemName: icon)
                    .font(.caption2)
            }

            Text(tag.name)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(ResponsiveDesign.captionFont())
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, ResponsiveDesign.spacing(10))
        .padding(.vertical, ResponsiveDesign.spacing(6))
        .background(tag.color)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }
}

// MARK: - Tag Selection Row

private struct TagSelectionRow: View {
    let tag: TicketTag
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Tag color indicator
                Circle()
                    .fill(tag.color)
                    .frame(width: 12, height: 12)

                // Icon
                if let icon = tag.icon {
                    Image(systemName: icon)
                        .foregroundColor(tag.color)
                        .font(ResponsiveDesign.bodyFont())
                        .frame(width: 24)
                }

                // Name
                Text(tag.name)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(isDisabled ? AppTheme.fontColor.opacity(0.4) : AppTheme.fontColor)

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? tag.color : AppTheme.fontColor.opacity(0.3))
                    .font(.title3)
            }
            .padding()
            .background(isSelected ? tag.color.opacity(0.1) : AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Inline Tag Display

/// Compact display of tags in a ticket row
struct TicketTagsDisplay: View {
    let tags: [TicketTag]
    let maxVisible: Int

    init(tags: [TicketTag], maxVisible: Int = 3) {
        self.tags = tags
        self.maxVisible = maxVisible
    }

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(4)) {
            ForEach(tags.prefix(maxVisible)) { tag in
                InlineTagBadge(tag: tag)
            }

            if tags.count > maxVisible {
                Text("+\(tags.count - maxVisible)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.fontColor.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }
}

// MARK: - Inline Tag Badge

struct InlineTagBadge: View {
    let tag: TicketTag

    var body: some View {
        HStack(spacing: 2) {
            if let icon = tag.icon {
                Image(systemName: icon)
                    .font(.system(size: 8))
            }

            Text(tag.name)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(tag.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tag.color.opacity(0.15))
        .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview {
    TicketTagPicker(
        selectedTags: .constant([TicketTag.defaults[0], TicketTag.defaults[2]])
    )
}

