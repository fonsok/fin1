import SwiftUI

// MARK: - Commission Calculation Explanation Sheet

struct CommissionCalculationExplanationSheet: View {
    let investment: Investment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var services
    @State private var statementSummary: InvestorInvestmentStatementSummary?

    // MARK: - Calculated Values
    private var buyAmount: Double {
        statementSummary?.statementInvestedAmount ?? 0.0
    }

    private var buyFees: Double {
        statementSummary?.statementBuyFees ?? 0.0
    }

    private var totalBuyCost: Double {
        statementSummary?.statementTotalBuyCost ?? investment.amount
    }

    private var netSellAmount: Double {
        statementSummary?.statementNetSellAmount ?? 0.0
    }

    // For backward compatibility, use totalBuyCost as investedAmount
    private var investedAmount: Double {
        totalBuyCost
    }

    private var currentValue: Double {
        investment.currentValue
    }

    private var netProfit: Double {
        currentValue - investedAmount
    }

    // Use pre-calculated values from summary (single source of truth - no inline calculations)
    private var grossProfit: Double {
        statementSummary?.statementGrossProfit ?? 0.0
    }

    // Use pre-calculated commission from summary (single source of truth)
    private var commission: Double {
        statementSummary?.statementCommission ?? 0.0
    }

    private var returnPercentage: Double {
        investment.performance
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
                        if statementSummary != nil {
                            if netProfit > 0 {
                                calculationTable
                            }
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
                                    text: "Gross profit is calculated from completed trades"
                                )
                                calculationStep(
                                    number: "2",
                                    text: "Trader receives \(services.configurationService.traderCommissionPercentage) commission on the gross profit (only when profit > 0)"
                                )
                                calculationStep(
                                    number: "3",
                                    text: "Net profit (after commission) is distributed to investors"
                                )
                                calculationStep(
                                    number: "4",
                                    text: "Return percentage is calculated as: (Gross Profit - Commission) / Invested Amount × 100"
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

                // Investment Breakdown
                if statementSummary != nil {
                    // Show Total Buy Cost and Net Sell Amount (matching collection bill format)
                    calculationTableRow(
                        label: "Total Investment Amount (Total Buy Cost)",
                        value: totalBuyCost.formattedAsLocalizedCurrency(),
                        isBold: true
                    )

                    Divider()

                    calculationTableRow(
                        label: "Net Sell Amount",
                        value: netSellAmount.formattedAsLocalizedCurrency(),
                        valueColor: netSellAmount >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
                    )
                } else {
                    // Fallback: show total investment amount
                    calculationTableRow(
                        label: "Invested Amount",
                        value: investedAmount.formattedAsLocalizedCurrency()
                    )
                }

                Divider()

                // Gross Profit
                calculationTableRow(
                    label: "Gross Profit (from trades), before commission & taxes",
                    value: grossProfit.formattedAsLocalizedCurrency(),
                    valueColor: AppTheme.accentGreen
                )

                Divider()

                // Commission
                calculationTableRow(
                    label: "Trader Commission (\(services.configurationService.traderCommissionPercentage))",
                    value: "-\(commission.formattedAsLocalizedCurrency())",
                    valueColor: AppTheme.fontColor.opacity(0.8)
                )

                Divider()

                // Return Percentage
                calculationTableRow(
                    label: "Return Percentage",
                    value: String(format: "%.2f%%", returnPercentage),
                    valueColor: returnPercentage >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
                    isBold: true
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private func calculationTableRow(label: String, value: String, valueColor: Color = AppTheme.fontColor, isBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isBold ? ResponsiveDesign.bodyFont().weight(.semibold) : ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
            Spacer()
            Text(value)
                .font(isBold ? ResponsiveDesign.bodyFont().weight(.semibold) : ResponsiveDesign.bodyFont())
                .foregroundColor(valueColor)
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
        let commissionRate = services.configurationService.traderCommissionRate
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
    }
}
