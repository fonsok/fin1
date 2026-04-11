import SwiftUI

/// Header block for customer detail (avatar, name, id, role/status badges).
struct CustomerDetailHeader: View {
    let customer: CustomerProfile

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Circle()
                .fill(AppTheme.accentLightBlue.opacity(0.2))
                .frame(width: ResponsiveDesign.spacing(80), height: ResponsiveDesign.spacing(80))
                .overlay(
                    Text(customer.fullName.prefix(2).uppercased())
                        .font(ResponsiveDesign.titleFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.accentLightBlue)
                )

            Text(customer.fullName)
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text("Kundennummer: \(customer.customerNumber)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                CSStatusBadge(text: customer.role.capitalized, color: AppTheme.accentLightBlue)
                CSStatusBadge(
                    text: customer.accountStatus.displayName,
                    color: customer.accountStatus == .active ? AppTheme.accentGreen : AppTheme.accentOrange
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}
