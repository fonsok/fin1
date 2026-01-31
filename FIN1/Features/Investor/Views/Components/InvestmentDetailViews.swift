import SwiftUI

struct NewInvestmentView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack {
                    Text("New Investment")
                        .font(ResponsiveDesign.titleFont())
                        .foregroundColor(AppTheme.fontColor)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }
}

// MARK: - Investment Detail View
/// Displays detailed information about an investment following MVVM architecture
struct InvestmentDetailView: View {
    @StateObject private var viewModel: InvestmentDetailViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Initialization
    init(investment: Investment) {
        self._viewModel = StateObject(wrappedValue: InvestmentDetailViewModel(investment: investment))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(20)) {
                        // Investment Header
                        VStack(spacing: ResponsiveDesign.spacing(12)) {
                            Text("Investment Details")
                                .font(ResponsiveDesign.headlineFont())
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.fontColor)

                            Text(viewModel.formattedAmount)
                                .font(ResponsiveDesign.titleFont())
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.accentGreen)
                        }
                        .padding()
                        .background(AppTheme.sectionBackground)
                        .cornerRadius(ResponsiveDesign.spacing(16))

                        // Investment Info
                        VStack(spacing: ResponsiveDesign.spacing(16)) {
                            InvestmentInfoRow(title: "Trader ID", value: viewModel.traderIdText)
                            InvestmentInfoRow(title: "Number of Investments", value: viewModel.numberOfInvestmentsText)
                            InvestmentInfoRow(title: "Specialization", value: viewModel.specializationText)
                            InvestmentInfoRow(title: "Status", value: viewModel.statusText)
                            InvestmentInfoRow(title: "Created", value: viewModel.formattedCreatedDate)
                            InvestmentInfoRow(title: "Last Updated", value: viewModel.formattedUpdatedDate)
                        }
                        .padding()
                        .background(AppTheme.sectionBackground)
                        .cornerRadius(ResponsiveDesign.spacing(16))

                        // Investment Reservations
                        if viewModel.hasInvestmentReservations {
                            VStack(spacing: ResponsiveDesign.spacing(12)) {
                                Text("Investment Reservations")
                                    .font(ResponsiveDesign.headlineFont())
                                    .foregroundColor(AppTheme.fontColor)

                                ForEach(viewModel.investmentReservations, id: \.id) { reservation in
                                    InvestmentReservationRow(reservation: reservation, viewModel: viewModel)
                                }
                            }
                            .padding()
                            .background(AppTheme.sectionBackground)
                            .cornerRadius(ResponsiveDesign.spacing(16))
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }
}

struct InvestmentInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Spacer()

            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
        }
    }
}

struct InvestmentReservationRow: View {
    let reservation: InvestmentReservation
    let viewModel: InvestmentDetailViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text("Investment #\(reservation.sequenceNumber)")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text(reservation.status.displayName)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            Spacer()

            Text(viewModel.formattedReservationAmount(reservation.allocatedAmount))
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.accentGreen)
        }
        .padding()
        .background(AppTheme.systemSecondaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

#Preview {
    NewInvestmentView()
}
