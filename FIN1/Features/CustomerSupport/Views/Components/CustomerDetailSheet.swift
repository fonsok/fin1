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
                    CustomerDetailHeader(customer: self.customer)

                    if let kyc = kycStatus {
                        CustomerDetailKYCSection(kyc: kyc)
                    }

                    CustomerDetailContactSection(customer: self.customer)

                    if self.customer.role.lowercased() == "investor" && self.viewModel.hasPermission(.viewCustomerInvestments) {
                        CustomerDetailInvestmentsSection(viewModel: self.viewModel) { investment in
                            self.selectedInvestment = investment
                        }
                    }

                    if self.customer.role.lowercased() == "trader" && self.viewModel.hasPermission(.viewCustomerTrades) {
                        CustomerDetailTradesSection(viewModel: self.viewModel) { trade in
                            self.selectedTrade = trade
                        }
                    }

                    if self.viewModel.hasPermission(.viewCustomerDocuments) {
                        CustomerDetailDocumentsSection(documents: self.documents)
                    }

                    if self.viewModel.hasPermission(.viewCustomerSupportHistory) {
                        CustomerDetailTicketsSection(viewModel: self.viewModel) { ticket in
                            self.selectedTicket = ticket
                        }
                    }

                    CustomerDetailActionsSection(customer: self.customer, viewModel: self.viewModel)
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Kundendetails")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        self.viewModel.clearSelectedCustomer()
                        self.dismiss()
                    }
                }
            }
            .sheet(isPresented: self.$viewModel.showCreateTicketSheet) {
                CreateTicketSheet(viewModel: self.viewModel)
            }
            .sheet(item: self.$selectedTicket) { ticket in
                TicketDetailSheet(ticket: ticket, viewModel: self.viewModel)
            }
            .sheet(item: self.$selectedInvestment) { investment in
                CSRInvestmentDetailSheet(
                    investment: investment,
                    customerName: self.customer.fullName
                )
            }
            .sheet(item: self.$selectedTrade) { trade in
                CSRTradeDetailSheet(
                    trade: trade,
                    customerName: self.customer.fullName
                )
            }
            .task {
                await self.viewModel.loadCustomerTickets(userId: self.customer.id)
            }
        }
    }
}
