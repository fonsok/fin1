import SwiftUI

// MARK: - Base Modal View Protocol
protocol BaseModalView: View {
    var title: String { get }
    var onDismiss: () -> Void { get }
}

// MARK: - Base Modal View Wrapper
struct BaseModalViewWrapper<Content: View>: BaseModalView {
    let title: String
    let onDismiss: () -> Void
    let content: () -> Content

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()
                self.content()
            }
            .navigationTitle(self.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: self.onDismiss, label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.fontColor)
                    })
                }
            }
        }
    }
}

// MARK: - Selection Modal Protocol
protocol SelectionModalView: BaseModalView {
    associatedtype Item: Identifiable
    var items: [Item] { get }
    var selectedItem: Item? { get }
    var onItemSelected: (Item) -> Void { get }
}

// MARK: - Generic Selection View
struct GenericSelectionView<Item: Identifiable, ItemView: View>: SelectionModalView {
    let title: String
    let onDismiss: () -> Void
    let items: [Item]
    let selectedItem: Item?
    let onItemSelected: (Item) -> Void
    let itemView: (Item, Bool) -> ItemView

    var body: some View {
        BaseModalViewWrapper(title: self.title, onDismiss: self.onDismiss) {
            List {
                ForEach(self.items) { item in
                    Button(action: { self.onItemSelected(item) }, label: {
                        self.itemView(item, self.selectedItem?.id == item.id)
                    })
                    .listRowBackground(self.selectedItem?.id == item.id ? AppTheme.accentGreen.opacity(0.2) : AppTheme.sectionBackground)
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Preview Helpers
struct PreviewItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String?
}

#Preview {
    GenericSelectionView(
        title: "Preview Selection",
        onDismiss: {},
        items: [
            PreviewItem(name: "Option 1", description: "Description 1"),
            PreviewItem(name: "Option 2", description: "Description 2")
        ],
        selectedItem: nil,
        onItemSelected: { _ in }
    ) { item, isSelected in
        HStack {
            VStack(alignment: .leading) {
                Text(item.name)
                    .foregroundColor(AppTheme.fontColor)
                if let description = item.description {
                    Text(description)
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .font(ResponsiveDesign.captionFont())
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(AppTheme.accentGreen)
            }
        }
    }
}
