import Combine
import SwiftUI

// MARK: - Invoice List View
/// Displays a list of invoices with filtering and search capabilities
struct InvoiceListView: View {
    @Environment(\.appServices) private var services
    @StateObject private var viewModel: InvoiceViewModel
    @State private var searchText = ""
    @State private var selectedFilter: InvoiceType?
    @State private var showingCreateInvoice = false

    init(invoiceService: any InvoiceServiceProtocol, notificationService: any NotificationServiceProtocol) {
        self._viewModel = StateObject(
            wrappedValue: InvoiceViewModel(invoiceService: invoiceService, notificationService: notificationService)
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                // Search and Filter Bar
                self.searchAndFilterBar

                // Invoice List
                if self.viewModel.isLoading {
                    self.loadingView
                } else if self.filteredInvoices.isEmpty {
                    self.emptyStateView
                } else {
                    self.invoiceList
                }
            }
            .navigationTitle("Rechnungen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Neu") {
                        self.showingCreateInvoice = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .sheet(isPresented: self.$showingCreateInvoice) {
                CreateInvoiceView(invoiceService: self.services.invoiceService, notificationService: self.services.notificationService)
            }
            .alert("Fehler", isPresented: self.$viewModel.showError) {
                Button("OK") {
                    self.viewModel.clearError()
                }
            } message: {
                Text(self.viewModel.errorMessage ?? "Ein unbekannter Fehler ist aufgetreten.")
            }
        }
        .onAppear {
            let currentUserId = Self.invoiceLookupKey(for: self.services.userService.currentUser)
            self.viewModel.loadInvoices(for: currentUserId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .invoiceDidChange)) { _ in
            let currentUserId = Self.invoiceLookupKey(for: self.services.userService.currentUser)
            self.viewModel.refreshInvoices(for: currentUserId)
        }
    }

    // MARK: - Search and Filter Bar

    private var searchAndFilterBar: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Rechnungen durchsuchen...", text: self.$searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Filter Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    InvoiceFilterChip(
                        title: "Alle",
                        isSelected: self.selectedFilter == nil
                    ) {
                        self.selectedFilter = nil
                    }

                    ForEach(InvoiceType.allCases, id: \.self) { type in
                        InvoiceFilterChip(
                            title: type.displayName,
                            isSelected: self.selectedFilter == type
                        ) {
                            self.selectedFilter = type
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Invoice List

    private var invoiceList: some View {
        List {
            ForEach(self.filteredInvoices) { invoice in
                InvoiceRowView(invoice: invoice, viewModel: self.viewModel) {
                    // Handle invoice selection
                    self.viewModel.selectedInvoice = invoice
                }
                .swipeActions(edge: .trailing) {
                    Button("Löschen", role: .destructive) {
                        self.viewModel.deleteInvoice(invoice)
                    }

                    Button("PDF") {
                        self.viewModel.generatePDF(for: invoice)
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(PlainListStyle())
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Rechnungen werden geladen...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            Image(systemName: "doc.text")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 3))
                .foregroundColor(.gray)

            Text("Keine Rechnungen gefunden")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.medium)

            Text("Erstellen Sie Ihre erste Rechnung oder passen Sie die Suchfilter an.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Rechnung erstellen") {
                self.showingCreateInvoice = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed Properties

    private var filteredInvoices: [Invoice] {
        self.viewModel.filteredInvoices(searchQuery: self.searchText, filterType: self.selectedFilter)
    }

    private static func invoiceLookupKey(for user: User?) -> String {
        guard let user else { return "current_user_id" }
        return user.customerNumber.isEmpty ? user.id : user.customerNumber
    }
}

// MARK: - Invoice Filter Chip Component

struct InvoiceFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action, label: {
            Text(self.title)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .padding(.horizontal, ResponsiveDesign.spacing(16))
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .background(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(20))
                        .fill(self.isSelected ? Color.accentColor : Color(.systemGray5))
                )
                .foregroundColor(self.isSelected ? .white : .primary)
        })
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Invoice Row View

struct InvoiceRowView: View {
    let invoice: Invoice
    let viewModel: InvoiceViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: self.onTap, label: {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Invoice Icon
                Image(systemName: self.invoice.type.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(self.invoice.type == .securitiesSettlement ? .blue : .orange)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(self.invoice.type == .securitiesSettlement ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                    )

                // Invoice Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(self.viewModel.formattedInvoiceNumber(for: self.invoice))
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(.primary)

                    Text(self.invoice.customerInfo.name)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)

                    Text(self.invoice.type.displayName)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Amount and Status
                VStack(alignment: .trailing, spacing: 4) {
                    Text(self.viewModel.formattedTotalAmount(for: self.invoice))
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    InvoiceStatusBadge(status: self.invoice.status)
                }
            }
            .padding(.vertical, ResponsiveDesign.spacing(8))
        })
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Invoice Status Badge Component

struct InvoiceStatusBadge: View {
    let status: InvoiceStatus

    var body: some View {
        Text(self.status.displayName)
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.medium)
            .padding(.horizontal, ResponsiveDesign.spacing(8))
            .padding(.vertical, ResponsiveDesign.spacing(4))
            .background(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                    .fill(self.status.color.opacity(0.2))
            )
            .foregroundColor(self.status.color)
    }
}

// MARK: - Preview

struct InvoiceListView_Previews: PreviewProvider {
    static var previews: some View {
        InvoiceListView(invoiceService: InvoiceService(), notificationService: NotificationService())
    }
}
