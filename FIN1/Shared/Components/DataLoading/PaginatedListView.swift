import SwiftUI

// MARK: - Paginated List View
struct PaginatedListView<T: Identifiable, Content: View>: View {
    @StateObject private var paginationCoordinator: PaginationCoordinator<T>
    let content: (T) -> Content

    init(
        config: PaginationConfig = .default,
        loadFunction: @escaping (Int, Int) async throws -> [T],
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self._paginationCoordinator = StateObject(wrappedValue: PaginationCoordinator(config: config, loadFunction: loadFunction))
        self.content = content
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            if paginationCoordinator.state == .loading && paginationCoordinator.items.isEmpty {
                loadingView
            } else if paginationCoordinator.state.isError {
                errorView
            } else {
                ScrollView {
                    LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                        ForEach(Array(paginationCoordinator.items.enumerated()), id: \.element.id) { index, item in
                            content(item)
                                .onAppear {
                                    paginationCoordinator.handlePrefetch(for: index)
                                }
                        }

                        // Loading more indicator
                        if paginationCoordinator.state == .loadingMore {
                            loadingMoreView
                        } else if !paginationCoordinator.hasMoreData && !paginationCoordinator.items.isEmpty {
                            noMoreDataView
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await paginationCoordinator.refresh()
                }
            }
        }
        .onAppear {
            Task {
                await paginationCoordinator.loadInitialData()
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
        .padding(.vertical, 40)
    }

    private var loadingMoreView: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accentLightBlue))
                .scaleEffect(0.8)
            Text("Loading more...")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .padding(.vertical, 16)
    }

    private var noMoreDataView: some View {
        Text("No more data")
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.5))
            .padding(.vertical, 16)
    }

    private var errorView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "exclamationmark.triangle")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 1.6))
                .foregroundColor(AppTheme.accentRed)
            Text("Failed to load data")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            Button("Retry") {
                Task {
                    await paginationCoordinator.refresh()
                }
            }
            .foregroundColor(AppTheme.accentLightBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
