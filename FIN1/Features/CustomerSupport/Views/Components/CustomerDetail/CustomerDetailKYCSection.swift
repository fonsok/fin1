import SwiftUI

/// KYC status section for customer detail.
struct CustomerDetailKYCSection: View {
    let kyc: CustomerKYCStatus

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(AppTheme.accentGreen)

                Text("KYC-Status")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                CSStatusBadge(text: self.kyc.overallStatus.displayName, color: self.kycStatusColor(self.kyc.overallStatus))
            }

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                KYCStatusRow(title: "E-Mail verifiziert", isComplete: self.kyc.emailVerified)
                KYCStatusRow(title: "Identität verifiziert", isComplete: self.kyc.identityVerified)
                KYCStatusRow(title: "Adresse verifiziert", isComplete: self.kyc.addressVerified)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private func kycStatusColor(_ status: CustomerKYCStatus.KYCOverallStatus) -> Color {
        switch status {
        case .complete: return AppTheme.accentGreen
        case .inProgress, .pendingReview: return AppTheme.accentOrange
        case .rejected, .expired: return AppTheme.accentRed
        }
    }
}
