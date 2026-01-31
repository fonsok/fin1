import SwiftUI

// MARK: - Data Models
struct UnderlyingItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
}

struct UnderlyingSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [UnderlyingItem]
}

// MARK: - Mock Data
let mockUnderlyingSections: [UnderlyingSection] = [
    UnderlyingSection(title: "Indices", items: [
        UnderlyingItem(name: "DAX", description: "Index - 84690"),
        UnderlyingItem(name: "MDAX", description: "Index - 846741"),
        UnderlyingItem(name: "Dow Jones", description: "Index ..."),
        UnderlyingItem(name: "S&P 500", description: ""),
        UnderlyingItem(name: "NASDAQ 100", description: ""),
        UnderlyingItem(name: "Euro Stoxx 50", description: ""),
        UnderlyingItem(name: "FTSE 100", description: ""),
        UnderlyingItem(name: "CAC 40", description: ""),
        UnderlyingItem(name: "SMI", description: "")
    ]),
    UnderlyingSection(title: "Aktien", items: [
        UnderlyingItem(name: "Apple", description: "Aktie - AAPL"),
        UnderlyingItem(name: "BMW", description: "Aktie - 519000"),
        UnderlyingItem(name: "Tesla", description: "Aktie - TSLA"),
        UnderlyingItem(name: "Microsoft", description: "Aktie - MSFT"),
        UnderlyingItem(name: "...", description: "")
    ]),
    UnderlyingSection(title: "Metalle", items: [
        UnderlyingItem(name: "Gold", description: "Rohstoff - 965515"),
        UnderlyingItem(name: "Silber", description: "Rohstoff - 965310"),
        UnderlyingItem(name: "...", description: "")
    ]),
    UnderlyingSection(title: "Währungen", items: [
        UnderlyingItem(name: "USD/JPY", description: "Devisen - 965991"),
        UnderlyingItem(name: "EUR/USD", description: "Devisen - 965275"),
        UnderlyingItem(name: "GBP/USD", description: "...")
    ])
]
// MARK: - Main View
struct UnderlyingAssetListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedUnderlying: String

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                List {
                    ForEach(mockUnderlyingSections) { section in
                        Section(header: Text(section.title).foregroundColor(AppTheme.fontColor).font(ResponsiveDesign.headlineFont())) {
                            ForEach(section.items) { item in
                                Button(action: {
                                    if item.name != "..." {
                                        selectedUnderlying = item.name
                                        dismiss()
                                    }
                                }, label: {
                                    HStack {
                                        Text(item.name)
                                            .foregroundColor(AppTheme.fontColor)
                                        Text(item.description)
                                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                                            .font(ResponsiveDesign.captionFont())
                                        Spacer()
                                    }
                                })
                                .listRowBackground(item.name == selectedUnderlying ? AppTheme.accentGreen : AppTheme.sectionBackground)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Basiswerte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }, label: {
                        Image(systemName: "xmark")
                    })
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    UnderlyingAssetListView(selectedUnderlying: .constant("DAX"))
}
