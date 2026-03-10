import SwiftUI

// MARK: - Customer Detail Sheet
/// Full-screen customer detail composed of CustomerDetail/* section views.
struct CustomerDetailSheet: View {
    let customer: CustomerProfile
    let kycStatus: CustomerKYCStatus?
    let investments: [CustomerInvestmentSummary]
    let documents: [CustomerDocumentSummary]
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTicket: SupportTicket?
    @State private var selectedInvestment: CustomerInvestmentSummary?
    @State private var selectedTrade: CustomerTradeSummary?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    CustomerDetailHeader(customer: customer)

                    if let kyc = kycStatus {
                        CustomerDetailKYCSection(kyc: kyc)
                    }

                    CustomerDetailContactSection(customer: customer)

                    if customer.role.lowercased() == "investor" && viewModel.hasPermission(.viewCustomerInvestments) {
                        CustomerDetailInvestmentsSection(viewModel: viewModel) { investment in
                            selectedInvestment = investment
                        }
                    }

                    if customer.role.lowercased() == "trader" && viewModel.hasPermission(.viewCustomerTrades) {
                        CustomerDetailTradesSection(viewModel: viewModel) { trade in
                            selectedTrade = trade
                        }
                    }

                    if viewModel.hasPermission(.viewCustomerDocuments) {
                        CustomerDetailDocumentsSection(documents: documents)
                    }

                    if viewModel.hasPermission(.viewCustomerSupportHistory) {
                        CustomerDetailTicketsSection(viewModel: viewModel) { ticket in
                            selectedTicket = ticket
                        }
                    }

                    CustomerDetailActionsSection(customer: customer, viewModel: viewModel)
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Kundendetails")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        viewModel.clearSelectedCustomer()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCreateTicketSheet) {
                CreateTicketSheet(viewModel: viewModel)
            }
            .sheet(item: $selectedTicket) { ticket in
                TicketDetailSheet(ticket: ticket, viewModel: viewModel)
            }
            .sheet(item: $selectedInvestment) { investment in
                CSRInvestmentDetailSheet(
                    investment: investment,
                    customerName: customer.fullName
                )
            }
            .sheet(item: $selectedTrade) { trade in
                CSRTradeDetailSheet(
                    trade: trade,
                    customerName: customer.fullName
                )
            }
            .task {
                await viewModel.loadCustomerTickets(customerId: customer.customerId)
            }
        }
    }
}
