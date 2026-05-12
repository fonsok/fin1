import SwiftUI

// MARK: - Commission Calculation Explanation Sheet

struct CommissionCalculationExplanationSheet: View {
    let investment: Investment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var services
    @State private var statementSummary: InvestorInvestmentStatementSummary?
    @State private var canonicalSummary: ServerInvestmentCanonicalSummary?

    // MARK: - SSOT
    // Values come from the same aggregator that populates the collection-bill line
    // items (statementSummary). ROI1 is computed locally from those line items.
    // ROI2 prefers the server-canonical `metadata.returnPercentage`
    // (`canonicalSummary`) and falls back to the same local derivation when the
    // backend value is unavailable.
    // See Documentation/RETURN_CALCULATION_SCHEMAS.md.

    private var grossProfit: Double {
        statementSummary?.statementGrossProfit ?? 0.0
    }

    private var commission: Double {
        statementSummary?.statementCommission ?? 0.0
    }

    private var investorNetProfit: Double {
        grossProfit - commission
    }

    private var totalBuyCost: Double {
        statementSummary?.statementTotalBuyCost ?? investment.amount
    }

    private var netSellAmount: Double {
        statementSummary?.statementNetSellAmount ?? 0.0
    }

    // ROI1 = Gross Profit / Total Buy Cost × 100 (pre-commission)
    private var grossProfitPercentageText: String? {
        guard totalBuyCost > 0 else { return nil }
        let percent = (grossProfit / totalBuyCost) * 100.0
        return String(format: "%+.2f%%", percent)
    }

    // ROI2 = (Gross Profit − Commission) / Total Buy Cost × 100 (post-commission)
    // Preference order: (1) server-canonical `metadata.returnPercentage`,
    // (2) local derivation from the statement summary.
    private var returnPercentage: Double? {
        if let canonical = canonicalSummary, canonical.hasReturnPercentage {
            return canonical.returnPercentage
        }
        guard let summary = statementSummary, summary.statementTotalBuyCost > 0 else { return nil }
        return (summary.statementGrossProfit - summary.statementCommission)
            / summary.statementTotalBuyCost * 100.0
    }

    private var returnPercentageText: String? {
        guard let value = returnPercentage else { return nil }
        return String(format: "%+.2f%%", value)
    }

    /// Drift warning: local-derived vs. server-canonical ROI2. Shown as a small
    /// info hint when both values exist and disagree by more than 0.05 %. The
    /// server value is authoritative; the warning surfaces legacy bills whose
    /// backfill hasn't run yet.
    private var returnPercentageDriftHint: String? {
        guard let canonical = canonicalSummary, canonical.hasReturnPercentage,
              let summary = statementSummary, summary.statementTotalBuyCost > 0 else { return nil }
        let local = (summary.statementGrossProfit - summary.statementCommission)
            / summary.statementTotalBuyCost * 100.0
        let delta = abs(local - canonical.returnPercentage)
        guard delta > 0.05 else { return nil }
        return String(format: "local derivation would be %+.2f%% (Δ %.2fpp)", local, delta)
    }

    private var tableCanShow: Bool {
        guard let s = statementSummary else { return false }
        return (s.statementNetSellAmount - s.statementTotalBuyCost) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                    Text("Profit & Return Calculation")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                        Text("The profit and return percentage shown in your investment represent the net amount you received after the trader commission has been deducted.")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)

                        // Calculation Table
                        if tableCanShow {
                            calculationTable
                        } else {
                            pendingSummaryView
                        }

                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                            Text("Calculation Scheme:")
                                .font(ResponsiveDesign.bodyFont())
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.fontColor)

                            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                                calculationStep(
                                    number: "1",
                                    text: "Gross Profit is calculated from completed trades (Net Sell Amount − Total Buy Cost)"
                                )
                                calculationStep(
                                    number: "2",
                                    text: "ROI1 (Gross Profit %) = Gross Profit / Total Buy Cost × 100 (classical, pre-commission)"
                                )
                                calculationStep(
                                    number: "3",
                                    text: "Trader receives \(services.configurationService.traderCommissionPercentage) commission on the gross profit (only when profit > 0)"
                                )
                                calculationStep(
                                    number: "4",
                                    text: "Net Profit = Gross Profit − Commission — distributed to investors"
                                )
                                calculationStep(
                                    number: "5",
                                    text: "Return (%) = ROI2 = Net Profit / Total Buy Cost × 100 (server-canonical, shown on your collection bill)"
                                )
                            }
                        }
                        .padding()
                        .background(AppTheme.sectionBackground)
                        .cornerRadius(ResponsiveDesign.spacing(8))

                        Text("Note: Commission is only charged on profitable trades. If a trade results in a loss or zero profit, no commission is deducted.")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            .italic()
                    }
                }
                .padding(ResponsiveDesign.horizontalPadding())
                .padding(.top, ResponsiveDesign.spacing(4))
                .padding(.bottom, ResponsiveDesign.spacing(16))
            }
            .background(AppTheme.screenBackground)
            .onAppear(perform: refreshStatementSummary)
            .onChange(of: investment.id) {
                refreshStatementSummary()
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

    // MARK: - Calculation Table

    private var calculationTable: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Your Investment Breakdown")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(0)) {
                // Header
                HStack {
                    Text("Item")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    Spacer()
                    Text("Amount")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
                .padding(.horizontal, ResponsiveDesign.spacing(12))
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .background(AppTheme.inputFieldBackground.opacity(0.5))

                Divider()

                // Total Buy Cost (Investor share, excl. residual credit)
                calculationTableRow(
                    label: "Total Investment Amount (Total Buy Cost)",
                    value: totalBuyCost.formattedAsLocalizedCurrency(),
                    isBold: true
                )

                Divider()

                // Net Sell Amount (Investor share)
                calculationTableRow(
                    label: "Net Sell Amount",
                    value: netSellAmount.formattedAsLocalizedCurrency(),
                    valueColor: netSellAmount >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
                )

                Divider()

                // Gross Profit (€) + Gross Profit (%) = ROI1 (classical ROI, pre-commission)
                calculationTableRow(
                    label: "Gross Profit (€) — before commission & taxes",
                    value: grossProfit.formattedAsLocalizedCurrency(),
                    secondaryValue: grossProfitPercentageText.map { "ROI1: \($0)" },
                    valueColor: AppTheme.accentGreen,
                    secondaryValueColor: AppTheme.accentGreen
                )

                Divider()

                // Commission (€)
                calculationTableRow(
                    label: "Trader Commission (\(services.configurationService.traderCommissionPercentage))",
                    value: "-\(commission.formattedAsLocalizedCurrency())",
                    valueColor: AppTheme.fontColor.opacity(0.8)
                )

                Divider()

                // Net Profit (€) — server canonical when available
                calculationTableRow(
                    label: "Net Profit (€) — after commission",
                    value: investorNetProfit.formattedAsLocalizedCurrency(),
                    valueColor: investorNetProfit >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
                    isBold: true
                )

                Divider()

                // Return (%) = ROI2 — server-canonical (metadata.returnPercentage)
                // with local derivation as fallback. Drift hint appears when
                // both sources disagree by > 0.05pp (legacy bill, awaiting
                // backfill).
                calculationTableRow(
                    label: "Return (%) — ROI2 (after commission)",
                    value: returnPercentageText ?? "pending",
                    secondaryValue: returnPercentageDriftHint,
                    valueColor: returnPercentageText == nil
                        ? AppTheme.fontColor.opacity(0.7)
                        : ((returnPercentage ?? 0) >= 0 ? AppTheme.accentGreen : AppTheme.accentRed),
                    secondaryValueColor: AppTheme.fontColor.opacity(0.5),
                    isBold: true
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private func calculationTableRow(
        label: String,
        value: String,
        secondaryValue: String? = nil,
        valueColor: Color = AppTheme.fontColor,
        secondaryValueColor: Color = AppTheme.fontColor.opacity(0.7),
        isBold: Bool = false
    ) -> some View {
        HStack {
            Text(label)
                .font(isBold ? ResponsiveDesign.bodyFont().weight(.semibold) : ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
            Spacer()
            VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(2)) {
                Text(value)
                    .font(isBold ? ResponsiveDesign.bodyFont().weight(.semibold) : ResponsiveDesign.bodyFont())
                    .foregroundColor(valueColor)

                if let secondaryValue {
                    Text(secondaryValue)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(secondaryValueColor)
                }
            }
        }
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .padding(.vertical, ResponsiveDesign.spacing(8))
    }

    private var pendingSummaryView: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Invoices are being prepared for this investment.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
            Text("Profit & Return details will appear automatically once the invoices arrive.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private func calculationStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(8)) {
            Text(number)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.accentLightBlue)
                .frame(width: 24, height: 24)
                .background(AppTheme.accentLightBlue.opacity(0.2))
                .clipShape(Circle())

            Text(text)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
        }
    }

    private func refreshStatementSummary() {
        let commissionRate = services.configurationService.effectiveCommissionRate
        statementSummary = InvestorInvestmentStatementAggregator.summarizeInvestment(
            investmentId: investment.id,
            poolTradeParticipationService: services.poolTradeParticipationService,
            tradeLifecycleService: services.tradeLifecycleService,
            invoiceService: services.invoiceService,
            investmentService: services.investmentService,
            calculationService: InvestorCollectionBillCalculationService(),
            commissionCalculationService: services.commissionCalculationService,
            commissionRate: commissionRate
        )

        let settlementService = services.settlementAPIService
        let investmentId = investment.id
        Task {
            let resolved = await ServerCalculatedReturnResolver.resolveCanonicalSummary(
                investmentId: investmentId,
                settlementAPIService: settlementService
            )
            await MainActor.run {
                self.canonicalSummary = resolved
            }
        }
    }
}
