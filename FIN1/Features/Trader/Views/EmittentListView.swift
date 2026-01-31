import SwiftUI

struct EmittentListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEmittent: String?

    struct Emittent: Identifiable {
        let id = UUID()
        let name: String
    }

    let alleEmittenten: [Emittent] = [
        .init(name: "BNP Paribas"),
        .init(name: "Citigroup"),
        .init(name: "DZ Bank"),
        .init(name: "Goldman Sachs"),
        .init(name: "HSBC"),
        .init(name: "J.P. Morgan"),
        .init(name: "Morgan Stanley"),
        .init(name: "Société Générale"),
        .init(name: "UBS"),
        .init(name: "Vontobel")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: {
                        selectedEmittent = "Alle"
                        dismiss()
                    }, label: {
                        Text("Alle")
                            .foregroundColor(AppTheme.fontColor)
                    })
                }

                Section(header: Text("Emittenten").foregroundColor(AppTheme.fontColor)) {
                    ForEach(alleEmittenten) { emittent in
                        Button(action: {
                            selectedEmittent = emittent.name
                            dismiss()
                        }, label: {
                            Text(emittent.name)
                                .foregroundColor(AppTheme.fontColor)
                        })
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Emittent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
