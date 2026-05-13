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
        if self.searchQuery.isEmpty {
            return self.availableTags
        }
        return self.availableTags.filter {
            $0.name.localizedCaseInsensitiveContains(self.searchQuery)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                // Selected tags
                if !self.selectedTags.isEmpty {
                    self.selectedTagsSection
                }

                // Search
                self.searchBar

                // Available tags
                self.tagList
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Tags auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") { self.dismiss() }
                }
            }
        }
    }

    // MARK: - Selected Tags Section

    private var selectedTagsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Ausgewählt (\(self.selectedTags.count)/\(self.maxTags))")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Spacer()

                if !self.selectedTags.isEmpty {
                    Button("Alle entfernen") {
                        self.selectedTags.removeAll()
                    }
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentRed)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(self.selectedTags) { tag in
                        SelectedTagChip(tag: tag) {
                            self.selectedTags.removeAll { $0.id == tag.id }
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

            TextField("Tag suchen...", text: self.$searchQuery)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            if !self.searchQuery.isEmpty {
                Button { self.searchQuery = "" } label: {
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
                ForEach(self.filteredTags) { tag in
                    TagSelectionRow(
                        tag: tag,
                        isSelected: self.selectedTags.contains { $0.id == tag.id },
                        isDisabled: self.selectedTags.count >= self.maxTags && !self.selectedTags.contains { $0.id == tag.id }
                    ) {
                        self.toggleTag(tag)
                    }
                }

                if self.filteredTags.isEmpty {
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
            self.selectedTags.remove(at: index)
        } else if self.selectedTags.count < self.maxTags {
            self.selectedTags.append(tag)
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
                    .font(ResponsiveDesign.captionFont())
            }

            Text(self.tag.name)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)

            Button(action: self.onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(ResponsiveDesign.captionFont())
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, ResponsiveDesign.spacing(10))
        .padding(.vertical, ResponsiveDesign.spacing(6))
        .background(self.tag.color)
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
        Button(action: self.onTap) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Tag color indicator
                Circle()
                    .fill(self.tag.color)
                    .frame(width: 12, height: 12)

                // Icon
                if let icon = tag.icon {
                    Image(systemName: icon)
                        .foregroundColor(self.tag.color)
                        .font(ResponsiveDesign.bodyFont())
                        .frame(width: 24)
                }

                // Name
                Text(self.tag.name)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(self.isDisabled ? AppTheme.fontColor.opacity(0.4) : AppTheme.fontColor)

                Spacer()

                // Selection indicator
                Image(systemName: self.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(self.isSelected ? self.tag.color : AppTheme.fontColor.opacity(0.3))
                    .font(ResponsiveDesign.headlineFont())
            }
            .padding()
            .background(self.isSelected ? self.tag.color.opacity(0.1) : AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(self.isDisabled)
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
            ForEach(self.tags.prefix(self.maxVisible)) { tag in
                InlineTagBadge(tag: tag)
            }

            if self.tags.count > self.maxVisible {
                Text("+\(self.tags.count - self.maxVisible)")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    .padding(.horizontal, ResponsiveDesign.spacing(6))
                    .padding(.vertical, ResponsiveDesign.spacing(2))
                    .background(AppTheme.fontColor.opacity(0.1))
                    .cornerRadius(ResponsiveDesign.spacing(6))
            }
        }
    }
}

// MARK: - Inline Tag Badge

struct InlineTagBadge: View {
    let tag: TicketTag

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(2)) {
            if let icon = tag.icon {
                Image(systemName: icon)
                    .font(ResponsiveDesign.captionFont())
            }

            Text(self.tag.name)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
        }
        .foregroundColor(self.tag.color)
        .padding(.horizontal, ResponsiveDesign.spacing(6))
        .padding(.vertical, ResponsiveDesign.spacing(2))
        .background(self.tag.color.opacity(0.15))
        .cornerRadius(ResponsiveDesign.spacing(6))
    }
}

// MARK: - Preview

#Preview {
    TicketTagPicker(
        selectedTags: .constant([TicketTag.defaults[0], TicketTag.defaults[2]])
    )
}

