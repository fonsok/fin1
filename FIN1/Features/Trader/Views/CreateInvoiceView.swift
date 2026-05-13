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
        self._viewModel = StateObject(
            wrappedValue: InvoiceViewModel(invoiceService: invoiceService, notificationService: notificationService)
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(6)) {
                // Header
                InvoiceViewSections.headerSection()

                // Trade Selection
                InvoiceViewSections.tradeSelectionSection(
                    selectedOrder: self.selectedOrder,
                    showingOrderSelection: self.$showingOrderSelection
                )

                // Customer Information
                InvoiceViewSections.customerInfoSection(
                    customerInfo: self.customerInfo,
                    isCustomerInfoComplete: self.isCustomerInfoComplete,
                    showingCustomerForm: self.$showingCustomerForm
                )

                // Preview Section
                if let order = selectedOrder {
                    InvoiceViewSections.previewSection(order: order)
                }

                Spacer()

                // Action Buttons
                InvoiceViewSections.actionButtonsSection(
                    isLoading: self.viewModel.isLoading,
                    canCreateInvoice: self.canCreateInvoice,
                    onCreateInvoice: self.createInvoice
                )
            }
            .padding()
            .navigationTitle("Rechnung erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        self.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Erstellen") {
                        self.createInvoice()
                    }
                    .disabled(!self.canCreateInvoice)
                }
            }
            .sheet(isPresented: self.$showingOrderSelection) {
                OrderSelectionView(selectedOrder: self.$selectedOrder)
            }
            .sheet(isPresented: self.$showingCustomerForm) {
                CustomerInfoFormView(customerInfo: self.$customerInfo)
            }
            .alert("Fehler", isPresented: self.$viewModel.showError) {
                Button("OK") {
                    self.viewModel.clearError()
                }
            } message: {
                Text(self.viewModel.errorMessage ?? "Ein unbekannter Fehler ist aufgetreten.")
            }
        }
    }

    // MARK: - Computed Properties

    private var canCreateInvoice: Bool {
        self.selectedOrder != nil && self.isCustomerInfoComplete && !self.viewModel.isLoading
    }

    private var isCustomerInfoComplete: Bool {
        !self.customerInfo.name.isEmpty &&
            !self.customerInfo.address.isEmpty &&
            !self.customerInfo.city.isEmpty &&
            !self.customerInfo.postalCode.isEmpty &&
            !self.customerInfo.taxNumber.isEmpty &&
            !self.customerInfo.depotNumber.isEmpty &&
            !self.customerInfo.bank.isEmpty &&
            !self.customerInfo.customerNumber.isEmpty
    }

    // MARK: - Private Methods

    private func createInvoice() {
        guard let order = selectedOrder else { return }

        Task {
            self.viewModel.createInvoice(from: order, customerInfo: self.customerInfo)
            await MainActor.run {
                self.dismiss()
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
