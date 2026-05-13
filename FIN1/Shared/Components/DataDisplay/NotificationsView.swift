import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: NotificationsViewModel
    private let notificationService: any NotificationServiceProtocol

    init(services: AppServices = .live) {
        self._viewModel = StateObject(wrappedValue: NotificationsViewModel(
            notificationService: services.notificationService,
            documentService: services.documentService,
            userService: services.userService
        ))
        self.notificationService = services.notificationService
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    // Title
                    Text("Notifications")
                        .font(ResponsiveDesign.titleFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)
                        .padding(.top, ResponsiveDesign.spacing(16))
                        .padding(.bottom, ResponsiveDesign.spacing(8))

                    // Filter Tabs
                    self.filterTabs

                    // Notifications List
                    self.notificationsList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: self.$viewModel.showDocumentArchive) {
                ArchivedItemsView(items: self.viewModel.archivedItems, notificationService: self.notificationService)
            }
            .navigationDestination(for: Document.self) { document in
                DocumentNavigationHelper.navigationDestination(for: document, appServices: self.appServices)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.fontColor)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        self.viewModel.markAllAsRead()
                    }) {
                        Text("Mark All Read")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.accentLightBlue)
                    }
                }
            }
        }
    }

    // MARK: - Filter Tabs
    private var filterTabs: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            ForEach(self.viewModel.availableFilters(), id: \.self) { filter in
                Button(action: {
                    self.viewModel.selectedFilter = filter
                }) {
                    Text(filter.displayName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(self.viewModel.selectedFilter == filter ? AppTheme.screenBackground : AppTheme.fontColor)
                        .padding(.horizontal, ResponsiveDesign.spacing(16))
                        .padding(.vertical, ResponsiveDesign.spacing(8))
                        .background(self.viewModel.selectedFilter == filter ? AppTheme.accentLightBlue : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(20))
                                .stroke(AppTheme.accentLightBlue, lineWidth: 1)
                        )
                        .cornerRadius(ResponsiveDesign.spacing(20))
                }
            }
        }
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .padding(.vertical, ResponsiveDesign.spacing(12))
    }

    // MARK: - Notifications List
    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                // Info banner about automatic archiving
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.accentLightBlue)

                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                        Text("Automatic Archiving")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        Text("Read notifications are automatically moved to archive after 24 hours")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }
                .padding(ResponsiveDesign.spacing(16))
                .background(AppTheme.accentLightBlue.opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(12))

                ForEach(self.viewModel.filteredItems) { item in
                    UnifiedItemCard(item: item, notificationService: self.notificationService)
                }

                // Info about automatic cleanup
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentLightBlue)

                        Text("Read notifications are automatically archived after 24 hours")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        Spacer()
                    }

                    // Archive button for older notifications
                    if self.viewModel.hasHiddenOlderItems {
                        Button(action: {
                            self.viewModel.showDocumentArchive = true
                        }) {
                            HStack {
                                Image(systemName: "archivebox")
                                    .font(ResponsiveDesign.captionFont())

                                Text("View Archived Items")
                                    .font(ResponsiveDesign.captionFont())
                                    .fontWeight(.medium)

                                Spacer()

                                Text("\(self.viewModel.archivedCount)")
                                    .font(ResponsiveDesign.captionFont())
                                    .padding(.horizontal, ResponsiveDesign.spacing(6))
                                    .padding(.vertical, ResponsiveDesign.spacing(2))
                                    .background(AppTheme.accentLightBlue.opacity(0.2))
                                    .cornerRadius(ResponsiveDesign.spacing(4))
                            }
                            .foregroundColor(AppTheme.accentLightBlue)
                            .padding(.horizontal, ResponsiveDesign.spacing(12))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            .background(AppTheme.sectionBackground)
                            .cornerRadius(ResponsiveDesign.spacing(8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, ResponsiveDesign.spacing(16))
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
            .padding(.horizontal, ResponsiveDesign.spacing(16))
            .padding(.bottom, ResponsiveDesign.spacing(16))
        }
    }
}

#Preview {
    NotificationsView()
}
