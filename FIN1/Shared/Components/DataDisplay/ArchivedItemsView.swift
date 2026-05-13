import SwiftUI

struct ArchivedItemsView: View {
    @Environment(\.dismiss) private var dismiss

    let items: [NotificationItem]
    let notificationService: any NotificationServiceProtocol

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                        if self.items.isEmpty {
                            self.emptyState
                        } else {
                            ForEach(self.items) { item in
                                UnifiedItemCard(item: item, notificationService: self.notificationService)
                            }
                        }
                    }
                    .padding(ResponsiveDesign.spacing(16))
                }
            }
            .navigationTitle("Archived Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "archivebox")
                .font(ResponsiveDesign.scaledSystemFont(size: 48))
                .foregroundColor(AppTheme.fontColor.opacity(0.3))

            Text("No Archived Items")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text("Read items appear here after the 24h archive window.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(ResponsiveDesign.spacing(32))
    }
}

#Preview {
    ArchivedItemsView(items: [], notificationService: NotificationService())
}

