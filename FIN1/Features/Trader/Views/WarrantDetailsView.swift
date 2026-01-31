import SwiftUI
import Foundation

// MARK: - Data Model & ViewModel
struct WarrantDetailItem: Identifiable {
    let id = UUID()
    let name: String
    var isSelected: Bool
    let isMandatory: Bool

    init(name: String, isSelected: Bool, isMandatory: Bool = false) {
        self.name = name
        self.isSelected = isSelected
        self.isMandatory = isMandatory
    }
}

final class WarrantDetailsViewModel: ObservableObject {
    @Published var items: [WarrantDetailItem]
    private let userDefaultsKey = "WarrantDetailsSelection"

    init() {
        let defaultItems: [WarrantDetailItem] = [
            // Special details: always selected and not toggleable
            WarrantDetailItem(name: "Kategorie", isSelected: true, isMandatory: true),
            WarrantDetailItem(name: "Basiswert", isSelected: true, isMandatory: true),
            WarrantDetailItem(name: "Richtung", isSelected: true, isMandatory: true),
            WarrantDetailItem(name: "Restlaufzeit", isSelected: true, isMandatory: true),
            WarrantDetailItem(name: "Strike Price Gap in %", isSelected: true, isMandatory: true),
            WarrantDetailItem(name: "Emittent", isSelected: true, isMandatory: true),

            // Configurable tiles/details
            WarrantDetailItem(name: "Strike Price", isSelected: true),
            WarrantDetailItem(name: "Bewertungstag", isSelected: true),
            WarrantDetailItem(name: "Brief-Kurs", isSelected: true),
            WarrantDetailItem(name: "Geld-Kurs", isSelected: false),
            WarrantDetailItem(name: "Implizite Volatilität", isSelected: false),
            WarrantDetailItem(name: "Omega", isSelected: false),
            WarrantDetailItem(name: "Subscription ratio", isSelected: true),
            WarrantDetailItem(name: "Ausübung", isSelected: false)
        ]

        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let storedSelection = try? JSONDecoder().decode([String: Bool].self, from: data) {
            self.items = defaultItems.map { item in
                guard let persisted = storedSelection[item.name], !item.isMandatory else {
                    return item
                }
                var mutableItem = item
                mutableItem.isSelected = persisted
                return mutableItem
            }
        } else {
            self.items = defaultItems
            saveSelection()
        }
    }

    deinit {
        print("🧹 WarrantDetailsViewModel deallocated")
    }

    func toggleSelection(for item: WarrantDetailItem) {
        // Mandatory details are always selected and cannot be toggled off
        guard !item.isMandatory,
              let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        items[index].isSelected.toggle()
        saveSelection()
    }

    private func saveSelection() {
        let selection = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.isSelected) })
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
// MARK: - Main View
struct WarrantDetailsView: View {
    @ObservedObject var viewModel: WarrantDetailsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    List {
                        ForEach(viewModel.items) { item in
                            Button(action: { viewModel.toggleSelection(for: item) }, label: {
                                HStack(spacing: ResponsiveDesign.spacing(16)) {
                                    Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                                        .foregroundColor(item.isSelected ? AppTheme.accentGreen : .gray)
                                        .font(.system(size: ResponsiveDesign.iconSize()))
                                    Text(item.name)
                                        .foregroundColor(AppTheme.fontColor)
                                }
                            })
                            .listRowBackground(AppTheme.sectionBackground)
                        }
                    }
                    .listStyle(.plain)

                    Button(action: { dismiss() }, label: {
                        Text("Apply")
                            .foregroundColor(AppTheme.fontColor)
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.buttonColor)
                            .cornerRadius(ResponsiveDesign.spacing(8))
                    })
                    .padding()
                }
            }
            .navigationTitle("Details - OS Warrants")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    WarrantDetailsView(viewModel: WarrantDetailsViewModel())
}
