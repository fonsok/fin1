import SwiftUI

/// Actions section for customer detail (create ticket, password reset, unlock).
struct CustomerDetailActionsSection: View {
    let customer: CustomerProfile
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Aktionen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                if self.viewModel.hasPermission(.createSupportTicket) {
                    CSActionButton(
                        icon: "ticket.fill",
                        title: "Support-Ticket erstellen",
                        color: AppTheme.accentLightBlue
                    ) {
                        self.viewModel.openCreateTicketSheet(userId: self.customer.id)
                    }
                }

                if self.viewModel.hasPermission(.resetCustomerPassword) {
                    CSActionButton(
                        icon: "key.fill",
                        title: "Passwort zurücksetzen",
                        color: AppTheme.accentOrange
                    ) {
                        Task {
                            await self.viewModel.initiatePasswordReset(customerNumber: self.customer.customerNumber)
                        }
                    }
                }

                if self.viewModel.hasPermission(.unlockCustomerAccount) && self.customer.accountStatus == .locked {
                    CSActionButton(
                        icon: "lock.open.fill",
                        title: "Konto entsperren",
                        color: AppTheme.accentGreen
                    ) {
                        Task {
                            await self.viewModel.unlockAccount(customerNumber: self.customer.customerNumber, reason: "Kundenanfrage")
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}
