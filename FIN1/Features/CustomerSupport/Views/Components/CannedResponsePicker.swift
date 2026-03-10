import SwiftUI

// MARK: - Canned Response Picker
/// Picker for selecting pre-written response templates.
/// Subviews: CannedResponse/CannedResponseCategoryChip, CannedResponseCard, BackendTemplateCard, CannedResponsePickerSearchBar.
struct CannedResponsePicker: View {
    @Binding var selectedResponse: CannedResponse?
    let placeholderValues: [String: String]
    let onSelect: (String) -> Void
    let csrRole: CSRRole?
    let templateService: TemplateAPIServiceProtocol?

    @State private var searchQuery = ""
    @State private var selectedCategory: CannedResponseCategory?
    @State private var backendTemplates: [ResponseTemplate] = []
    @State private var isLoadingTemplates = false
    @State private var useBackendTemplates = false
    @Environment(\.dismiss) private var dismiss

    init(
        selectedResponse: Binding<CannedResponse?>,
        placeholderValues: [String: String],
        csrRole: CSRRole? = nil,
        templateService: TemplateAPIServiceProtocol? = nil,
        onSelect: @escaping (String) -> Void
    ) {
        _selectedResponse = selectedResponse
        self.placeholderValues = placeholderValues
        self.csrRole = csrRole
        self.templateService = templateService
        self.onSelect = onSelect
    }

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

    private var filteredBackendTemplates: [ResponseTemplate] {
        var templates = backendTemplates
        if let category = selectedCategory, let templateCategory = mapToTemplateCategory(category) {
            templates = templates.filter { $0.category == templateCategory }
        }
        if !searchQuery.isEmpty {
            templates = templates.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                $0.body.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        return templates
    }

    private func mapToTemplateCategory(_ category: CannedResponseCategory) -> TemplateCategory? {
        switch category {
        case .greeting: return .greeting
        case .closing: return .closing
        case .technical: return .technical
        case .billing: return .transactions
        default: return nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                CannedResponsePickerSearchBar(searchQuery: $searchQuery)
                sourceToggle
                categoryFilter
                if useBackendTemplates {
                    backendTemplateList
                } else {
                    responseList
                }
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Textbausteine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
            .task {
                await loadBackendTemplates()
            }
        }
    }

    private var sourceToggle: some View {
        Group {
            if templateService != nil && csrRole != nil {
                HStack {
                    Picker("Quelle", selection: $useBackendTemplates) {
                        Text("Lokal").tag(false)
                        Text("Backend").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)

                    if isLoadingTemplates {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, ResponsiveDesign.spacing(4))
            }
        }
    }

    private var backendTemplateList: some View {
        ScrollView {
            LazyVStack(spacing: ResponsiveDesign.spacing(8)) {
                ForEach(filteredBackendTemplates) { template in
                    BackendTemplateCard(
                        template: template,
                        placeholderValues: placeholderValues
                    ) {
                        let filledContent = fillPlaceholders(in: template.body, with: placeholderValues)
                        onSelect(filledContent)
                        Task {
                            try? await templateService?.recordUsage(templateId: template.id, ticketId: nil)
                        }
                        dismiss()
                    }
                }

                if filteredBackendTemplates.isEmpty {
                    backendEmptyState
                }
            }
            .padding()
        }
    }

    private var backendEmptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            if isLoadingTemplates {
                ProgressView()
                Text("Lade Templates vom Server...")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            } else {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: ResponsiveDesign.iconSize() * 2))
                    .foregroundColor(AppTheme.fontColor.opacity(0.3))

                Text("Keine Backend-Templates gefunden")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Button("Lokale Templates verwenden") {
                    useBackendTemplates = false
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(40))
    }

    private func loadBackendTemplates() async {
        guard let service = templateService, let role = csrRole else { return }
        isLoadingTemplates = true
        defer { isLoadingTemplates = false }
        if let service = service as? TemplateAPIService {
            backendTemplates = await service.fetchTemplatesWithFallback(for: role, category: nil)
            if !backendTemplates.isEmpty {
                useBackendTemplates = true
            }
        }
    }

    private func fillPlaceholders(in text: String, with values: [String: String]) -> String {
        var result = text
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
            result = result.replacingOccurrences(of: "{{\(key.uppercased())}}", with: value)
        }
        return result
    }

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
                .font(.system(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.fontColor.opacity(0.3))

            Text("Keine Textbausteine gefunden")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(40))
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
        ],
        csrRole: .level1,
        templateService: nil
    ) { content in
        print("Selected: \(content)")
    }
}
