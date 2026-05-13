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
            if self.paginationCoordinator.state == .loading && self.paginationCoordinator.items.isEmpty {
                self.loadingView
            } else if self.paginationCoordinator.state.isError {
                self.errorView
            } else {
                ScrollView {
                    LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                        ForEach(Array(self.paginationCoordinator.items.enumerated()), id: \.element.id) { index, item in
                            self.content(item)
                                .onAppear {
                                    self.paginationCoordinator.handlePrefetch(for: index)
                                }
                        }

                        // Loading more indicator
                        if self.paginationCoordinator.state == .loadingMore {
                            self.loadingMoreView
                        } else if !self.paginationCoordinator.hasMoreData && !self.paginationCoordinator.items.isEmpty {
                            self.noMoreDataView
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await self.paginationCoordinator.refresh()
                }
            }
        }
        .onAppear {
            Task {
                await self.paginationCoordinator.loadInitialData()
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
                    await self.paginationCoordinator.refresh()
                }
            }
            .foregroundColor(AppTheme.accentLightBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
