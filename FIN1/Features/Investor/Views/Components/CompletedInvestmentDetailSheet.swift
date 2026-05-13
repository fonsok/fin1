import SwiftUI

// MARK: - Completed Investment Detail Sheet
struct CompletedInvestmentDetailSheet: View {
    @StateObject private var viewModel: CompletedInvestmentDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var services

    init(investment: Investment) {
        self._viewModel = StateObject(wrappedValue: CompletedInvestmentDetailViewModel(investment: investment))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        self.summarySection
                        self.financialOverviewSection
                        self.taxBreakdownSection
                        self.netOutcomeSection
                        self.investmentDetailsSection
                        self.tradeLinesSection
                    }
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.vertical, ResponsiveDesign.spacing(12))
                }
            }
            .navigationTitle("Investment \(self.viewModel.investmentNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
            .task {
                self.viewModel.reconfigure(with: self.services)
            }
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack(alignment: .firstTextBaseline, spacing: ResponsiveDesign.spacing(8)) {
                Text(self.viewModel.traderName)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                self.statusBadge
            }

            self.detailRow(title: "Trader Specialization", value: self.viewModel.traderSpecialization)
            self.detailRow(title: "Trade Nr.", value: self.viewModel.tradeNumberText)
            self.detailRow(title: "Created On", value: self.viewModel.createdDateText)
            self.detailRow(title: "Completed On", value: self.viewModel.completedDateText)
            self.detailRow(title: "Number of Investments", value: self.viewModel.numberOfInvestmentsText)
            self.detailRow(title: "Active Investments", value: self.viewModel.activeInvestmentCountText)
            self.detailRow(title: "Completed Investments", value: self.viewModel.completedInvestmentCountText)
            self.detailRow(title: "Your Quantity (Total)", value: "\(self.viewModel.totalInvestorQuantityText) Stk")
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var financialOverviewSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            self.sectionHeader(title: "Financial Overview")

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    self.metricView(title: "Current Value", value: self.viewModel.currentValueText, valueColor: AppTheme.accentLightBlue)
                    self.metricView(title: "Invested Amount", value: self.viewModel.investedAmountText)
                }

                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    self.metricView(
                        title: "Profit",
                        value: self.viewModel.profitText,
                        valueColor: self.viewModel.isProfitPositive ? AppTheme.accentGreen : AppTheme.accentRed
                    )

                    self.metricView(
                        title: "Return",
                        value: self.viewModel.returnPercentageText,
                        valueColor: self.viewModel.isProfitPositive ? AppTheme.accentGreen : AppTheme.accentRed
                    )
                }
            }
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var taxBreakdownSection: some View {
        // Mirror the trader's "Steuerliche Abzüge und Endergebnis" table styling
        let profitBeforeTaxes = max(viewModel.profit, 0)
        let capitalGainsTax = InvoiceTaxCalculator.calculateCapitalGainsTax(for: profitBeforeTaxes)
        let solidaritySurcharge = InvoiceTaxCalculator.calculateSolidaritySurcharge(for: capitalGainsTax)
        let churchTax = InvoiceTaxCalculator.calculateChurchTax(for: capitalGainsTax)
        let totalTaxes = capitalGainsTax + solidaritySurcharge + churchTax

        return VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            // Section header
            Text("Steuerliche Abzüge und Endergebnis")
                .tradeCalculationSectionHeaderStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, ResponsiveDesign.spacing(8))

            Divider()

            // Tax header row (Steuerart / Basis / Satz / Betrag)
            HStack {
                Text("Steuerart")
                    .tradeCalculationHeaderStyle()
                Spacer()
                Text("Basis (€)")
                    .tradeCalculationHeaderStyle()
                Spacer()
                Text("Satz")
                    .tradeCalculationHeaderStyle()
                Spacer()
                Text("Betrag (€)")
                    .tradeCalculationHeaderStyle()
            }
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .background(AppTheme.inputFieldBackground)

            Divider()

            // Abgeltungssteuer
            TaxRow(
                name: "Abgeltungs-\nsteuer",
                base: profitBeforeTaxes,
                rate: "25%",
                amount: capitalGainsTax
            )

            // Solidaritätszuschlag
            TaxRow(
                name: "Solidaritäts\nzuschlag",
                base: capitalGainsTax,
                rate: "5,5%",
                amount: solidaritySurcharge
            )

            // Kirchensteuer (optional)
            TaxRow(
                name: "Kirchensteuer\n(optional)",
                base: capitalGainsTax,
                rate: "8%",
                amount: churchTax
            )

            Divider()

            // Total taxes row ("Gesamtsteuerlast")
            HStack {
                Text("Gesamtsteuerlast")
                    .tradeCalculationBoldStyle()
                Spacer()
                Text("")
                Spacer()
                Text("")
                Spacer()
                Text(totalTaxes.formatted(.currency(code: "EUR")))
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.accentRed)
            }
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .padding(.horizontal, ResponsiveDesign.spacing(12))
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var netOutcomeSection: some View {
        // Mirror the trader's "Ergebnis nach Steuern und Gebühren" banner
        let netResult = self.viewModel.netProfitAfterCharges

        return VStack(spacing: ResponsiveDesign.spacing(0)) {
            HStack {
                Text("Ergebnis nach Steuern und Gebühren")
                    .tradeCalculationBoldStyle()
                Spacer()
                Text(self.viewModel.netProfitAfterChargesText)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.bold)
                    .foregroundColor(netResult >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
            }
            .padding(.vertical, ResponsiveDesign.spacing(12))
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .background(AppTheme.accentLightBlue.opacity(0.2))
        }
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private var investmentDetailsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            self.sectionHeader(title: "Investment Details")

            if self.viewModel.hasInvestmentDetails {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(self.viewModel.investmentDetails) { investment in
                        self.investmentDetailRow(investment)
                    }
                }
            } else {
                Text("No investment reservations recorded for this investment.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    .padding(.vertical, ResponsiveDesign.spacing(4))
            }
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var tradeLinesSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            self.sectionHeader(title: "Trades for this Investment")

            if self.viewModel.tradeLineItems.isEmpty {
                Text("No trade participations recorded for this investment.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    .padding(.vertical, ResponsiveDesign.spacing(4))
            } else {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(self.viewModel.tradeLineItems) { line in
                        self.tradeLineRow(line)
                    }
                }
            }
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Components

    private var statusBadge: some View {
        Text(self.viewModel.statusText)
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.semibold)
            .padding(.horizontal, ResponsiveDesign.spacing(6))
            .padding(.vertical, ResponsiveDesign.spacing(2))
            .background(self.viewModel.statusColor.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(6))
                    .stroke(self.viewModel.statusColor.opacity(0.6), lineWidth: 1)
            )
            .cornerRadius(ResponsiveDesign.spacing(6))
            .foregroundColor(self.viewModel.statusColor)
    }

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(ResponsiveDesign.headlineFont())
            .foregroundColor(AppTheme.fontColor)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Spacer()

            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
        }
    }

    private func metricView(title: String, value: String, valueColor: Color = AppTheme.fontColor) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text(title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Text(value)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func investmentDetailRow(_ investment: CompletedInvestmentDetailViewModel.InvestmentDetail) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
            HStack {
                Text("Investment #\(investment.sequenceNumber)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Text(investment.statusText)
                    .font(ResponsiveDesign.captionFont())
                    .padding(.horizontal, ResponsiveDesign.spacing(4))
                    .padding(.vertical, ResponsiveDesign.spacing(1))
                    .background(investment.statusColor.opacity(0.2))
                    .cornerRadius(ResponsiveDesign.spacing(4))
                    .foregroundColor(investment.statusColor)
            }

            self.detailRow(title: "Allocated Amount", value: investment.amountText)

            if investment.isLocked {
                Text("Investment is locked until completion.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            }
        }
        .padding(ResponsiveDesign.spacing(10))
        .background(AppTheme.systemSecondaryBackground.opacity(0.4))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private func tradeLineRow(_ line: CompletedInvestmentDetailViewModel.TradeLineItem) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
            HStack {
                Text("Trade #\(String(format: "%03d", line.tradeNumber)) – \(line.symbol)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Text(line.tradeDate.formatted(Date.FormatStyle.localizedDate))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            HStack {
                Text("\(line.formattedQuantity) Stk")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(4)) {
                    Text("\(line.formattedUnitPrice) / Stk")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    Text(line.formattedTotalAmount)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
        .padding(ResponsiveDesign.spacing(10))
        .background(AppTheme.systemSecondaryBackground.opacity(0.4))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.fontColor.opacity(0.2))
            .frame(height: 1)
    }
}

#Preview {
    let _ = InvestmentReservation(
        id: UUID().uuidString,
        sequenceNumber: 1,
        status: .completed,
        actualInvestmentId: "INV-1",
        allocatedAmount: 1_250,
        reservedAt: Date(),
        isLocked: false
    )

    let investment = Investment(
        id: UUID().uuidString,
        batchId: UUID().uuidString,
        investorId: UUID().uuidString,
        investorName: "Sarah Smith",
        traderId: UUID().uuidString,
        traderName: "Anna Fischer",
        amount: 10_000,
        currentValue: 12_500,
        date: Date(),
        status: .completed,
        performance: 25.5,
        numberOfTrades: 12,
        sequenceNumber: 1,
        createdAt: Date().addingTimeInterval(-86_400 * 45),
        updatedAt: Date().addingTimeInterval(-86_400 * 2),
        completedAt: Date().addingTimeInterval(-86_400 * 2),
        specialization: "Momentum Trading",
        reservationStatus: .completed
    )

    CompletedInvestmentDetailSheet(investment: investment)
        .environment(\.appServices, AppServices.live)
}
