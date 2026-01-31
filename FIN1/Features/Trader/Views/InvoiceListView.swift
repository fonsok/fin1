import SwiftUI
import Combine

// MARK: - Invoice List View
/// Displays a list of invoices with filtering and search capabilities
struct InvoiceListView: View {
    @Environment(\.appServices) private var services
    @StateObject private var viewModel: InvoiceViewModel
    @State private var searchText = ""
    @State private var selectedFilter: InvoiceType?
    @State private var showingCreateInvoice = false

    init(invoiceService: any InvoiceServiceProtocol, notificationService: any NotificationServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: InvoiceViewModel(invoiceService: invoiceService, notificationService: notificationService))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                // Search and Filter Bar
                searchAndFilterBar

                // Invoice List
                if viewModel.isLoading {
                    loadingView
                } else if filteredInvoices.isEmpty {
                    emptyStateView
                } else {
                    invoiceList
                }
            }
            .navigationTitle("Rechnungen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Neu") {
                        showingCreateInvoice = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .sheet(isPresented: $showingCreateInvoice) {
                CreateInvoiceView(invoiceService: services.invoiceService, notificationService: services.notificationService)
            }
            .alert("Fehler", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "Ein unbekannter Fehler ist aufgetreten.")
            }
        }
        .onAppear {
            // Get actual current user ID
            let currentUserId = services.userService.currentUser?.customerId ?? services.userService.currentUser?.id ?? "current_user_id"
            viewModel.loadInvoices(for: currentUserId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .invoiceDidChange)) { _ in
            // Refresh invoices when a new one is added
            let currentUserId = services.userService.currentUser?.customerId ?? services.userService.currentUser?.id ?? "current_user_id"
            viewModel.refreshInvoices(for: currentUserId)
        }
    }

    // MARK: - Search and Filter Bar

    private var searchAndFilterBar: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Rechnungen durchsuchen...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Filter Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    InvoiceFilterChip(
                        title: "Alle",
                        isSelected: selectedFilter == nil
                    ) {
                        selectedFilter = nil
                    }

                    ForEach(InvoiceType.allCases, id: \.self) { type in
                        InvoiceFilterChip(
                            title: type.displayName,
                            isSelected: selectedFilter == type
                        ) {
                            selectedFilter = type
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
            ForEach(filteredInvoices) { invoice in
                InvoiceRowView(invoice: invoice, viewModel: viewModel) {
                    // Handle invoice selection
                    viewModel.selectedInvoice = invoice
                }
                .swipeActions(edge: .trailing) {
                    Button("Löschen", role: .destructive) {
                        viewModel.deleteInvoice(invoice)
                    }

                    Button("PDF") {
                        viewModel.generatePDF(for: invoice)
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
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Keine Rechnungen gefunden")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.medium)

            Text("Erstellen Sie Ihre erste Rechnung oder passen Sie die Suchfilter an.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Rechnung erstellen") {
                showingCreateInvoice = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed Properties

    private var filteredInvoices: [Invoice] {
        viewModel.filteredInvoices(searchQuery: searchText, filterType: selectedFilter)
    }
}

// MARK: - Invoice Filter Chip Component

struct InvoiceFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action, label: {
            Text(title)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .padding(.horizontal, ResponsiveDesign.spacing(16))
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .background(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(20))
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
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
        Button(action: onTap, label: {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Invoice Icon
                Image(systemName: invoice.type.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(invoice.type == .securitiesSettlement ? .blue : .orange)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(invoice.type == .securitiesSettlement ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                    )

                // Invoice Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.formattedInvoiceNumber(for: invoice))
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(.primary)

                    Text(invoice.customerInfo.name)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)

                    Text(invoice.type.displayName)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Amount and Status
                VStack(alignment: .trailing, spacing: 4) {
                    Text(viewModel.formattedTotalAmount(for: invoice))
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    InvoiceStatusBadge(status: invoice.status)
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
        Text(status.displayName)
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.medium)
            .padding(.horizontal, ResponsiveDesign.spacing(8))
            .padding(.vertical, ResponsiveDesign.spacing(4))
            .background(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                    .fill(status.color.opacity(0.2))
            )
            .foregroundColor(status.color)
    }
}

// MARK: - Preview

struct InvoiceListView_Previews: PreviewProvider {
    static var previews: some View {
        InvoiceListView(invoiceService: InvoiceService(), notificationService: NotificationService())
    }
}
