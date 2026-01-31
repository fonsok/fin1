import SwiftUI

// MARK: - Order Selection View
struct OrderSelectionView: View {
    @Binding var selectedOrder: OrderBuy?
    @Environment(\.dismiss) private var dismiss

    // Mock orders for demonstration
    private let mockOrders = [
        OrderBuy(
            id: "1",
            traderId: "trader1",
            symbol: "DAX PUT",
            description: "DAX Optionsschein PUT",
            quantity: 1000,
            price: 1.20,
            totalAmount: 1200.00,
            status: .completed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: "PUT",
            underlyingAsset: "DAX",
            wkn: "VT1234",
            category: "Optionsschein",
            strike: 15000.0, orderInstruction: "market",
            limitPrice: nil
        )
    ]

    var body: some View {
        NavigationStack {
            List(mockOrders) { order in
                Button(action: {
                    selectedOrder = order
                    dismiss()
                }, label: {
                    OrderSelectionCard(order: order) {
                        // This won't be called since we're handling the tap above
                    }
                })
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Order auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Customer Info Form View
struct CustomerInfoFormView: View {
    @Binding var customerInfo: CustomerInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Persönliche Daten") {
                    TextField("Name", text: $customerInfo.name)
                    TextField("Straße und Hausnummer", text: $customerInfo.address)
                    TextField("Stadt", text: $customerInfo.city)
                    TextField("Postleitzahl", text: $customerInfo.postalCode)
                }

                Section("Steuerliche Daten") {
                    TextField("Steuernummer", text: $customerInfo.taxNumber)
                }

                Section("Bankdaten") {
                    TextField("Depotnummer", text: $customerInfo.depotNumber)
                    TextField("Bank", text: $customerInfo.bank)
                    TextField("Kundennummer", text: $customerInfo.customerNumber)
                }
            }
            .navigationTitle("Kundendaten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        dismiss()
                    }
                }
            }
        }
    }
}











