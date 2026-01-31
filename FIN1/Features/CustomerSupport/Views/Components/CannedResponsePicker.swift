import SwiftUI

// MARK: - Canned Response Picker

/// Picker for selecting pre-written response templates
struct CannedResponsePicker: View {
    @Binding var selectedResponse: CannedResponse?
    let placeholderValues: [String: String]
    let onSelect: (String) -> Void

    @State private var searchQuery = ""
    @State private var selectedCategory: CannedResponseCategory?
    @Environment(\.dismiss) private var dismiss

    private var filteredResponses: [CannedResponse] {
        var responses = CannedResponse.defaults

        if let category = selectedCategory {
            responses = responses.filter { $0.category == category }
        }

        if !searchQuery.isEmpty {
            responses = responses.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                $0.content.localizedCaseInsensitiveContains(searchQuery) ||
                ($0.shortcut?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }

        return responses
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                categoryFilter
                responseList
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Textbausteine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.fontColor.opacity(0.5))

            TextField("Suchen oder /Kürzel eingeben...", text: $searchQuery)
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

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                CannedResponseCategoryChip(
                    title: "Alle",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(CannedResponseCategory.allCases, id: \.rawValue) { category in
                    CannedResponseCategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, ResponsiveDesign.spacing(8))
        }
        .background(AppTheme.sectionBackground.opacity(0.5))
    }

    // MARK: - Response List

    private var responseList: some View {
        ScrollView {
            LazyVStack(spacing: ResponsiveDesign.spacing(8)) {
                ForEach(filteredResponses) { response in
                    CannedResponseCard(
                        response: response,
                        placeholderValues: placeholderValues
                    ) {
                        let filledContent = response.fillPlaceholders(placeholderValues)
                        onSelect(filledContent)
                        dismiss()
                    }
                }

                if filteredResponses.isEmpty {
                    emptyState
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.fontColor.opacity(0.3))

            Text("Keine Textbausteine gefunden")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(40))
    }
}

// MARK: - Canned Response Category Chip

private struct CannedResponseCategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Image(systemName: icon)
                    .font(ResponsiveDesign.captionFont())
                Text(title)
                    .font(ResponsiveDesign.captionFont())
            }
            .foregroundColor(isSelected ? .white : AppTheme.fontColor)
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .padding(.vertical, ResponsiveDesign.spacing(6))
            .background(isSelected ? AppTheme.accentLightBlue : AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))
        }
    }
}

// MARK: - Canned Response Card

private struct CannedResponseCard: View {
    let response: CannedResponse
    let placeholderValues: [String: String]
    let onSelect: () -> Void

    @State private var isExpanded = false

    private var previewContent: String {
        let filled = response.fillPlaceholders(placeholderValues)
        if filled.count > 100 {
            return String(filled.prefix(100)) + "..."
        }
        return filled
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                // Header
                HStack {
                    Image(systemName: response.category.icon)
                        .foregroundColor(AppTheme.accentLightBlue)
                        .font(ResponsiveDesign.captionFont())

                    Text(response.title)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Spacer()

                    if let shortcut = response.shortcut {
                        Text(shortcut)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(AppTheme.accentOrange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accentOrange.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                // Preview
                Text(isExpanded ? response.fillPlaceholders(placeholderValues) : previewContent)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .lineLimit(isExpanded ? nil : 3)
                    .multilineTextAlignment(.leading)

                // Placeholders warning
                if !response.placeholders.isEmpty {
                    let missingPlaceholders = response.placeholders.filter { placeholderValues[$0] == nil }
                    if !missingPlaceholders.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("Platzhalter: \(missingPlaceholders.joined(separator: ", "))")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(AppTheme.accentOrange)
                    }
                }

                // Expand toggle
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Weniger" : "Mehr anzeigen")
                                .font(.system(size: 11))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(AppTheme.accentLightBlue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    CannedResponsePicker(
        selectedResponse: .constant(nil),
        placeholderValues: [
            "customerName": "Max Mustermann",
            "ticketNumber": "TKT-12345",
            "agentName": "Stefan Müller"
        ]
    ) { content in
        print("Selected: \(content)")
    }
}

