import SwiftUI

struct DerivateCategoryListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: String
    @State private var showDevelopmentNotification = false

    struct DerivateCategory: Identifiable {
        let id = UUID()
        let name: String
        let description: String?
        let isSupported: Bool
    }

    let derivateKategorien: [DerivateCategory] = [
        .init(name: "Optionsschein", description: "Klassische Optionsscheine", isSupported: true),
        .init(name: "Inline OS", description: "Inline Optionsscheine", isSupported: false),
        .init(name: "Factor-OS", description: "Factor Optionsscheine", isSupported: false),
        .init(name: "Discount OS", description: "Discount Optionsscheine", isSupported: false),
        .init(name: "Knockout", description: "Knock-out Zertifikate", isSupported: false)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                List {
                    ForEach(self.derivateKategorien) { kategorie in
                        Button(action: {
                            if kategorie.isSupported {
                                self.selectedCategory = kategorie.name
                                self.dismiss()
                            } else {
                                // Show notification for unsupported categories
                                self.showDevelopmentNotification = true
                                // Keep current selection (don't change to unsupported category)
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                                    HStack {
                                        Text(kategorie.name)
                                            .foregroundColor(kategorie.isSupported ? AppTheme.fontColor : AppTheme.fontColor.opacity(0.5))
                                            .font(ResponsiveDesign.headlineFont())

                                        if !kategorie.isSupported {
                                            Text("(Entwicklung)")
                                                .foregroundColor(AppTheme.accentLightBlue)
                                                .font(ResponsiveDesign.captionFont())
                                                .fontWeight(.medium)
                                        }
                                    }

                                    if let description = kategorie.description {
                                        Text(description)
                                            .foregroundColor(
                                                kategorie.isSupported ? AppTheme.fontColor.opacity(0.7) : AppTheme.fontColor.opacity(0.4)
                                            )
                                            .font(ResponsiveDesign.captionFont())
                                    }
                                }

                                Spacer()

                                if kategorie.name == self.selectedCategory {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.accentGreen)
                                        .font(ResponsiveDesign.headlineFont())
                                }
                            }
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                        }
                        .listRowBackground(
                            kategorie.name == self.selectedCategory ? AppTheme.accentGreen.opacity(0.2) : AppTheme.sectionBackground
                        )
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Derivate Kategorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { self.dismiss() }, label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.fontColor)
                    })
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("übernehmen") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentGreen)
                    .fontWeight(.semibold)
                }
            }
            .alert("Entwicklung", isPresented: self.$showDevelopmentNotification) {
                Button("OK") { }
            } message: {
                Text(
                    "Derzeit wird nur die Derivate-Kategorie 'Optionsschein' unterstützt. Andere Kategorien werden evtl. in zukünftigen Versionen verfügbar sein."
                )
            }
        }
    }
}

// MARK: - Preview
#Preview {
    DerivateCategoryListView(selectedCategory: .constant("Optionsschein"))
}
