import SwiftUI

// MARK: - Create Invoice View
/// Allows users to create new invoices from trades
struct CreateInvoiceView: View {
    @StateObject private var viewModel: InvoiceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedOrder: OrderBuy?
    @State private var customerInfo = CustomerInfo(
        name: "",
        address: "",
        city: "",
        postalCode: "",
        taxNumber: "",
        depotNumber: "",
        bank: "",
        customerNumber: ""
    )
    @State private var showingOrderSelection = false
    @State private var showingCustomerForm = false

    init(invoiceService: any InvoiceServiceProtocol, notificationService: any NotificationServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: InvoiceViewModel(invoiceService: invoiceService, notificationService: notificationService))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(6)) {
                // Header
                InvoiceViewSections.headerSection()

                // Trade Selection
                InvoiceViewSections.tradeSelectionSection(
                    selectedOrder: selectedOrder,
                    showingOrderSelection: $showingOrderSelection
                )

                // Customer Information
                InvoiceViewSections.customerInfoSection(
                    customerInfo: customerInfo,
                    isCustomerInfoComplete: isCustomerInfoComplete,
                    showingCustomerForm: $showingCustomerForm
                )

                // Preview Section
                if let order = selectedOrder {
                    InvoiceViewSections.previewSection(order: order)
                }

                Spacer()

                // Action Buttons
                InvoiceViewSections.actionButtonsSection(
                    isLoading: viewModel.isLoading,
                    canCreateInvoice: canCreateInvoice,
                    onCreateInvoice: createInvoice
                )
            }
            .padding()
            .navigationTitle("Rechnung erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Erstellen") {
                        createInvoice()
                    }
                    .disabled(!canCreateInvoice)
                }
            }
            .sheet(isPresented: $showingOrderSelection) {
                OrderSelectionView(selectedOrder: $selectedOrder)
            }
            .sheet(isPresented: $showingCustomerForm) {
                CustomerInfoFormView(customerInfo: $customerInfo)
            }
            .alert("Fehler", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "Ein unbekannter Fehler ist aufgetreten.")
            }
        }
    }

    // MARK: - Computed Properties

    private var canCreateInvoice: Bool {
        selectedOrder != nil && isCustomerInfoComplete && !viewModel.isLoading
    }

    private var isCustomerInfoComplete: Bool {
        !customerInfo.name.isEmpty &&
        !customerInfo.address.isEmpty &&
        !customerInfo.city.isEmpty &&
        !customerInfo.postalCode.isEmpty &&
        !customerInfo.taxNumber.isEmpty &&
        !customerInfo.depotNumber.isEmpty &&
        !customerInfo.bank.isEmpty &&
        !customerInfo.customerNumber.isEmpty
    }

    // MARK: - Private Methods

    private func createInvoice() {
        guard let order = selectedOrder else { return }

        Task {
            viewModel.createInvoice(from: order, customerInfo: customerInfo)
            await MainActor.run {
                dismiss()
            }
        }
    }

}

// MARK: - Preview

struct CreateInvoiceView_Previews: PreviewProvider {
    static var previews: some View {
        CreateInvoiceView(invoiceService: InvoiceService(), notificationService: NotificationService())
    }
}
