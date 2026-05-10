import SwiftUI

/// Admin/Buchhaltung — Beleg-Suche (Rechnungen, Gutschriften, Eigenbelege, Statements …).
///
/// Backend: Cloud Functions `searchDocuments` / `getDocumentByObjectId`
/// (siehe `backend/parse-server/cloud/functions/admin/reports/searchDocuments.js`).
struct DocumentSearchView: View {
    @StateObject private var viewModel: DocumentSearchViewModel
    @Environment(\.appServices) private var services

    init(searchService: any DocumentSearchAPIServiceProtocol) {
        _viewModel = StateObject(wrappedValue: DocumentSearchViewModel(searchService: searchService))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                filtersSection
                resultsHeader
                resultsSection
            }
            .padding()
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Belege")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.items.isEmpty {
                viewModel.scheduleDebouncedSearch(immediate: true)
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Filters

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Filter")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)

            TextField("Belegnummer (z. B. CB-2026-0000001)", text: $viewModel.filters.documentNumber)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: viewModel.filters.documentNumber) { _, _ in
                    viewModel.scheduleDebouncedSearch()
                }

            TextField("Volltext (Name, Belegnummer)", text: $viewModel.filters.freeText)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .onChange(of: viewModel.filters.freeText) { _, _ in
                    viewModel.scheduleDebouncedSearch()
                }

            HStack {
                TextField("Investment-ID", text: $viewModel.filters.investmentId)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.filters.investmentId) { _, _ in
                        viewModel.scheduleDebouncedSearch()
                    }
                TextField("Trade-ID", text: $viewModel.filters.tradeId)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.filters.tradeId) { _, _ in
                        viewModel.scheduleDebouncedSearch()
                    }
            }

            TextField("User-ID (Parse objectId)", text: $viewModel.filters.userId)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .onChange(of: viewModel.filters.userId) { _, _ in
                    viewModel.scheduleDebouncedSearch()
                }

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                DatePicker(
                    "Von",
                    selection: Binding(
                        get: { viewModel.filters.dateFrom ?? Date.distantPast },
                        set: { viewModel.filters.dateFrom = $0 }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .opacity(viewModel.filters.dateFrom == nil ? 0.5 : 1)

                Toggle(isOn: Binding(
                    get: { viewModel.filters.dateFrom != nil },
                    set: { newValue in
                        viewModel.filters.dateFrom = newValue ? (viewModel.filters.dateFrom ?? Date()) : nil
                        viewModel.scheduleDebouncedSearch(immediate: true)
                    }
                )) {
                    EmptyView()
                }
                .labelsHidden()
            }

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                DatePicker(
                    "Bis",
                    selection: Binding(
                        get: { viewModel.filters.dateTo ?? Date() },
                        set: { viewModel.filters.dateTo = $0 }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .opacity(viewModel.filters.dateTo == nil ? 0.5 : 1)

                Toggle(isOn: Binding(
                    get: { viewModel.filters.dateTo != nil },
                    set: { newValue in
                        viewModel.filters.dateTo = newValue ? (viewModel.filters.dateTo ?? Date()) : nil
                        viewModel.scheduleDebouncedSearch(immediate: true)
                    }
                )) {
                    EmptyView()
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
                Text("Belegtyp")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ResponsiveDesign.spacing(8)) {
                        ForEach(DocumentSearchViewModel.selectableTypes, id: \.self) { type in
                            typePill(type)
                        }
                    }
                }
            }

            HStack {
                Button("Filter zurücksetzen") {
                    viewModel.clearAllFilters()
                }
                .buttonStyle(.bordered)
                Spacer()
                Button {
                    viewModel.scheduleDebouncedSearch(immediate: true)
                } label: {
                    Label("Suchen", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private func typePill(_ type: DocumentType) -> some View {
        let isSelected = viewModel.filters.types.contains(type)
        return Button {
            viewModel.toggleType(type)
        } label: {
            Text(type.displayName)
                .font(ResponsiveDesign.captionFont())
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(isSelected ? AppTheme.accentLightBlue.opacity(0.2) : AppTheme.sectionBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                        .stroke(isSelected ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.2), lineWidth: 1)
                )
                .foregroundColor(AppTheme.fontColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results

    private var resultsHeader: some View {
        HStack {
            Text(headerTitle)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
            Spacer()
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }

    private var headerTitle: String {
        if let total = lastTotal {
            return "Treffer (\(viewModel.items.count) / \(total))"
        }
        return "Treffer (\(viewModel.items.count))"
    }

    private var lastTotal: Int? { nil }

    @ViewBuilder
    private var resultsSection: some View {
        if let error = viewModel.errorMessage {
            errorBanner(message: error)
        }
        if viewModel.items.isEmpty && !viewModel.isLoading {
            emptyState
        } else {
            LazyVStack(spacing: ResponsiveDesign.spacing(10)) {
                ForEach(viewModel.items) { document in
                    NavigationLink {
                        DocumentNavigationHelper.navigationDestination(for: document, appServices: services)
                    } label: {
                        documentRow(document)
                    }
                    .buttonStyle(.plain)
                    .task {
                        await viewModel.loadMoreIfNeeded(currentItem: document)
                    }
                }
                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func documentRow(_ document: Document) -> some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: document.type.icon)
                .foregroundColor(document.type.color)
                .font(ResponsiveDesign.headlineFont())
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(document.accountingDocumentNumber ?? document.name)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(document.type.displayName)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
                Text(document.uploadedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }

    private var emptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("Keine Belege für die aktuellen Filter.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(40))
    }

    private func errorBanner(message: String) -> some View {
        Text(message)
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(.white)
            .padding(ResponsiveDesign.spacing(10))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.accentRed)
            .cornerRadius(ResponsiveDesign.spacing(8))
    }
}
