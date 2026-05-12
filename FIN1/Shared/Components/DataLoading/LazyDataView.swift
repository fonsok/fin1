import SwiftUI

// MARK: - Lazy Data View
struct LazyDataView<T: Identifiable, Content: View>: View {
    @State private var items: [T] = []
    @State private var isLoading = false
    @State private var error: Error?

    let loadFunction: () async throws -> [T]
    let content: (T) -> Content

    init(
        loadFunction: @escaping () async throws -> [T],
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.loadFunction = loadFunction
        self.content = content
    }

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                loadingView
            } else if let error = error {
                errorView(error)
            } else {
                LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                    ForEach(items) { item in
                        content(item)
                    }
                }
            }
        }
        .onAppear {
            loadData()
        }
    }

    private func loadData() {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        Task {
            do {
                let data = try await loadFunction()
                await MainActor.run {
                    self.items = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accentLightBlue))
            Text("Loading...")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(40))
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "exclamationmark.triangle")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.accentRed)
            Text("Failed to load data")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            Text(error.localizedDescription)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Retry") {
                loadData()
            }
            .foregroundColor(AppTheme.accentLightBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(40))
    }
}
