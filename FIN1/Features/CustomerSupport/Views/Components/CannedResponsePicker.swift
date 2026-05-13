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
        if !self.searchQuery.isEmpty {
            responses = responses.filter {
                $0.title.localizedCaseInsensitiveContains(self.searchQuery) ||
                    $0.content.localizedCaseInsensitiveContains(self.searchQuery) ||
                    ($0.shortcut?.localizedCaseInsensitiveContains(self.searchQuery) ?? false)
            }
        }
        return responses
    }

    private var filteredBackendTemplates: [ResponseTemplate] {
        var templates = self.backendTemplates
        if let category = selectedCategory, let templateCategory = mapToTemplateCategory(category) {
            templates = templates.filter { $0.category == templateCategory }
        }
        if !self.searchQuery.isEmpty {
            templates = templates.filter {
                $0.title.localizedCaseInsensitiveContains(self.searchQuery) ||
                    $0.body.localizedCaseInsensitiveContains(self.searchQuery)
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
                CannedResponsePickerSearchBar(searchQuery: self.$searchQuery)
                self.sourceToggle
                self.categoryFilter
                if self.useBackendTemplates {
                    self.backendTemplateList
                } else {
                    self.responseList
                }
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Textbausteine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { self.dismiss() }
                }
            }
            .task {
                await self.loadBackendTemplates()
            }
        }
    }

    private var sourceToggle: some View {
        Group {
            if self.templateService != nil && self.csrRole != nil {
                HStack {
                    Picker("Quelle", selection: self.$useBackendTemplates) {
                        Text("Lokal").tag(false)
                        Text("Backend").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)

                    if self.isLoadingTemplates {
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
                ForEach(self.filteredBackendTemplates) { template in
                    BackendTemplateCard(
                        template: template,
                        placeholderValues: self.placeholderValues
                    ) {
                        let filledContent = self.fillPlaceholders(in: template.body, with: self.placeholderValues)
                        self.onSelect(filledContent)
                        Task {
                            try? await self.templateService?.recordUsage(templateId: template.id, ticketId: nil)
                        }
                        self.dismiss()
                    }
                }

                if self.filteredBackendTemplates.isEmpty {
                    self.backendEmptyState
                }
            }
            .padding()
        }
    }

    private var backendEmptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            if self.isLoadingTemplates {
                ProgressView()
                Text("Lade Templates vom Server...")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            } else {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                    .foregroundColor(AppTheme.fontColor.opacity(0.3))

                Text("Keine Backend-Templates gefunden")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Button("Lokale Templates verwenden") {
                    self.useBackendTemplates = false
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(40))
    }

    private func loadBackendTemplates() async {
        guard let service = templateService, let role = csrRole else { return }
        self.isLoadingTemplates = true
        defer { isLoadingTemplates = false }
        if let service = service as? TemplateAPIService {
            self.backendTemplates = await service.fetchTemplatesWithFallback(for: role, category: nil)
            if !self.backendTemplates.isEmpty {
                self.useBackendTemplates = true
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
                    isSelected: self.selectedCategory == nil
                ) {
                    self.selectedCategory = nil
                }

                ForEach(CannedResponseCategory.allCases, id: \.rawValue) { category in
                    CannedResponseCategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: self.selectedCategory == category
                    ) {
                        self.selectedCategory = category
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
                ForEach(self.filteredResponses) { response in
                    CannedResponseCard(
                        response: response,
                        placeholderValues: self.placeholderValues
                    ) {
                        let filledContent = response.fillPlaceholders(self.placeholderValues)
                        self.onSelect(filledContent)
                        self.dismiss()
                    }
                }

                if self.filteredResponses.isEmpty {
                    self.emptyState
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
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
