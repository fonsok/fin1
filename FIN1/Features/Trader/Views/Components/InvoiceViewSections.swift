import SwiftUI

// MARK: - Invoice View Sections
struct InvoiceViewSections {

    // MARK: - Header Section
    static func headerSection() -> some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "doc.text.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Neue Rechnung erstellen")
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.semibold)

            Text("Wählen Sie einen Trade und geben Sie die Kundendaten ein")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Trade Selection Section
    static func tradeSelectionSection(
        selectedOrder: OrderBuy?,
        showingOrderSelection: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trade auswählen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)

            if let order = selectedOrder {
                OrderSelectionCard(order: order) {
                    showingOrderSelection.wrappedValue = true
                }
            } else {
                Button(action: {
                    showingOrderSelection.wrappedValue = true
                }, label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Trade auswählen")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .fill(Color.accentColor.opacity(0.3))
                    )
                })
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Customer Information Section
    static func customerInfoSection(
        customerInfo: CustomerInfo,
        isCustomerInfoComplete: Bool,
        showingCustomerForm: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kundeninformationen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)

            if isCustomerInfoComplete {
                CustomerInfoCard(customerInfo: customerInfo) {
                    showingCustomerForm.wrappedValue = true
                }
            } else {
                Button(action: {
                    showingCustomerForm.wrappedValue = true
                }, label: {
                    HStack {
                        Image(systemName: "person.circle")
                        Text("Kundendaten eingeben")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .fill(Color.accentColor.opacity(0.3))
                    )
                })
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Preview Section
    static func previewSection(order: OrderBuy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rechnungsvorschau")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    Text("Trade:")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(order.symbol)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Stück:")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(String(format: "%.0f Stück", order.quantity))
                        .font(ResponsiveDesign.bodyFont())
                }

                HStack {
                    Text("Kurs:")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(order.price.formattedAsLocalizedCurrency())
                        .font(ResponsiveDesign.bodyFont())
                }

                Divider()

                HStack {
                    Text("Geschätzter Gesamtbetrag:")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)

                    Spacer()

                    Text(calculateEstimatedTotal(order: order).formattedAsLocalizedCurrency())
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                    .fill(Color(.systemGray6))
            )
        }
    }

    // MARK: - Action Buttons Section
    static func actionButtonsSection(
        isLoading: Bool,
        canCreateInvoice: Bool,
        onCreateInvoice: @escaping () -> Void
    ) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Rechnung wird erstellt...")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Rechnung erstellen") {
                    onCreateInvoice()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(!canCreateInvoice)
            }
        }
    }

    // MARK: - Helper Methods

    private static func calculateEstimatedTotal(order: OrderBuy) -> Double {
        let securitiesTotal = order.quantity * order.price
        let fees = 7.00 + 2.00 + 1.50 // Order fee + Exchange fee + Foreign costs
        return securitiesTotal + fees
    }
}











