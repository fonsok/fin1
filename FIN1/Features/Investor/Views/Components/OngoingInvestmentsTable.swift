import SwiftUI

// MARK: - Ongoing Investments Table Component

struct OngoingInvestmentsTable: View {
    let pools: [InvestmentRow]
    @Binding var columnWidths: [String: CGFloat]
    let totalAmount: Double
    let totalProfit: Double?
    let totalReturn: Double?
    let onDeleteInvestment: (InvestmentRow) -> Void
    let onShowStatusInfo: () -> Void

    // Table Configuration Constants (DRY)
    private var tableColumnSpacing: CGFloat {
        ResponsiveDesign.spacing(16)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                // Table Header
                headerContent(columnWidths: columnWidths, forMeasurement: false)
                    .frame(minHeight: 44)
                    .padding(.horizontal, ResponsiveDesign.spacing(12))
                    .padding(.vertical, ResponsiveDesign.spacing(6))

                // Table Rows
                ForEach(Array(pools.enumerated()), id: \.element.id) { index, pool in
                    ongoingInvestmentRow(pool: pool, isEven: index % 2 == 0, columnWidths: columnWidths)
                }

                // Total Row
                totalRow(columnWidths: columnWidths)
            }
        }
        .overlay(alignment: .topLeading) {
            // Hidden measurement views
            ZStack {
                // Measure header cells (reuses headerContent for DRY)
                headerContent(columnWidths: [:], forMeasurement: true)

                // Measure data rows
                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    ForEach(pools) { pool in
                        HStack(spacing: tableColumnSpacing) {
                            Text("Investment \(pool.sequenceNumber)")
                                .font(ResponsiveDesign.bodyFont())
                                .measureWidth(column: "pot")

                            HStack(spacing: ResponsiveDesign.spacing(2)) {
                                if pool.isDeletable {
                                    if !pool.statusDisplayText.isEmpty {
                                        Text(pool.statusDisplayText)
                                            .font(ResponsiveDesign.bodyFont())
                                    }
                                    Image(systemName: "trash")
                                        .font(.system(size: ResponsiveDesign.iconSize() * 0.8))
                                } else {
                                    Text(pool.statusDisplayText)
                                        .font(ResponsiveDesign.bodyFont())
                                }
                            }
                            .measureWidth(column: "status")

                            Text(pool.amount.formattedAsLocalizedCurrency())
                                .font(ResponsiveDesign.bodyFont())
                                .measureWidth(column: "amount")

                            if let profit = pool.profit {
                                Text(profit.formattedAsLocalizedCurrency())
                                    .font(ResponsiveDesign.bodyFont())
                                    .measureWidth(column: "profit")
                            } else {
                                // Show placeholder for completed pools
                                let placeholder = pool.status == .completed ? 0.0.formattedAsLocalizedCurrency() : ""
                                Text(placeholder)
                                    .font(ResponsiveDesign.bodyFont())
                                    .measureWidth(column: "profit")
                            }

                            if let returnPercentage = pool.returnPercentage {
                                Text("\(String(format: "%.0f", returnPercentage))%")
                                    .font(ResponsiveDesign.bodyFont())
                                    .measureWidth(column: "return")
                            } else {
                                // Show placeholder for completed pools
                                let placeholder = pool.status == .completed ? "0%" : ""
                                Text(placeholder)
                                    .font(ResponsiveDesign.bodyFont())
                                    .measureWidth(column: "return")
                            }

                            InvestmentDocRefView(verrechnungNumber: pool.docNumber, rechnungNumber: pool.invoiceNumber)
                                .measureWidth(column: "docRef")
                        }
                    }

                    // Measure total row
                    HStack(spacing: tableColumnSpacing) {
                        Text("Total")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.semibold)
                            .measureWidth(column: "pot")

                        Text("")
                            .measureWidth(column: "status")

                        Text(totalAmount.formattedAsLocalizedCurrency())
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.semibold)
                            .measureWidth(column: "amount")

                        if let profit = totalProfit {
                            Text(profit.formattedAsLocalizedCurrency())
                                .font(ResponsiveDesign.bodyFont())
                                .fontWeight(.semibold)
                                .measureWidth(column: "profit")
                        } else {
                            Text("not yet\navailable")
                                .font(ResponsiveDesign.bodyFont())
                                .measureWidth(column: "profit")
                        }

                        if let returnPercentage = totalReturn {
                            Text("\(String(format: "%.0f", returnPercentage))%")
                                .font(ResponsiveDesign.bodyFont())
                                .fontWeight(.semibold)
                                .measureWidth(column: "return")
                        } else {
                            Text("not yet\navailable")
                                .font(ResponsiveDesign.bodyFont())
                                .measureWidth(column: "return")
                        }

                        Text("")
                            .measureWidth(column: "docRef")
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: true)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onPreferenceChange(ColumnWidthPreferenceKey.self) { widths in
            // Add small padding to each column width for breathing room
            columnWidths = widths.mapValues { width in
                max(width + ResponsiveDesign.spacing(4), 40) // Minimum 40pt width
            }
        }
    }

    // MARK: - Header Content Builder (DRY)

    /// Builds the header content structure - used for both display and measurement
    @ViewBuilder
    private func headerContent(columnWidths: [String: CGFloat], forMeasurement: Bool = false) -> some View {
        HStack(spacing: tableColumnSpacing) {
            Group {
                Text("Investment")
                    .font(ResponsiveDesign.bodyFont())
            }
            .modifier(HeaderCellModifier(
                columnKey: "pot",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .leading
            ))

            Group {
                HStack(spacing: ResponsiveDesign.spacing(2)) {
                    Text("Status")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(forMeasurement ? .clear : AppTheme.fontColor)

                    if forMeasurement {
                        Image(systemName: "info.circle")
                            .font(.system(size: ResponsiveDesign.iconSize() * 0.8))
                    } else {
                        Button(action: onShowStatusInfo, label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: ResponsiveDesign.iconSize() * 0.8))
                                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        })
                    }
                }
            }
            .modifier(HeaderCellModifier(
                columnKey: "status",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .leading
            ))

            Group {
                Text("Amount (€)")
                    .font(ResponsiveDesign.bodyFont())
            }
            .modifier(HeaderCellModifier(
                columnKey: "amount",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .trailing
            ))

            Group {
                Text("Profit (€)")
                    .font(ResponsiveDesign.bodyFont())
            }
            .modifier(HeaderCellModifier(
                columnKey: "profit",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .trailing
            ))

            Group {
                Text("Return (%)")
                    .font(ResponsiveDesign.bodyFont())
            }
            .modifier(HeaderCellModifier(
                columnKey: "return",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .trailing
            ))

            Group {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Beleg /")
                    Text("Rechnung")
                }
                .font(ResponsiveDesign.bodyFont())
            }
            .modifier(HeaderCellModifier(
                columnKey: "docRef",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .leading
            ))
        }
    }

    // MARK: - Header Cell Modifier

    private struct HeaderCellModifier: ViewModifier {
        let columnKey: String
        let columnWidths: [String: CGFloat]
        let forMeasurement: Bool
        let alignment: Alignment

        func body(content: Content) -> some View {
            if forMeasurement {
                content
                    .measureWidth(column: columnKey)
            } else {
                content
                    .foregroundColor(AppTheme.fontColor)
                    .frame(width: columnWidths[columnKey] ?? defaultWidth, alignment: alignment)
            }
        }

        private var defaultWidth: CGFloat {
            switch columnKey {
            case "pot": return 60
            case "status": return 80
            case "amount": return 110
            case "profit": return 110
            case "return": return 90
            case "docRef": return 100
            default: return 80
            }
        }
    }

    // MARK: - Table Rows

    private func ongoingInvestmentRow(pool: InvestmentRow, isEven: Bool, columnWidths: [String: CGFloat]) -> some View {
        HStack(spacing: tableColumnSpacing) {
            // Investment Number
            Text("Investment \(pool.sequenceNumber)")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(width: columnWidths["pot"] ?? 60, alignment: .leading)

            // Status
            HStack(spacing: ResponsiveDesign.spacing(2)) {
                if pool.isDeletable {
                    if !pool.statusDisplayText.isEmpty {
                        Text(pool.statusDisplayText)
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)
                    }

                    Button(action: {
                        print("🗑️ Trash button tapped for investment \(pool.investmentId)")
                        onDeleteInvestment(pool)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: ResponsiveDesign.iconSize() * 0.8))
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Text(pool.statusDisplayText)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(pool.status.displayColor)
                }
            }
            .frame(width: columnWidths["status"] ?? 80, alignment: pool.isDeletable ? .center : .leading)
            .contentShape(Rectangle()) // Ensure entire status area is tappable

            // Amount
            Text(pool.amount.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(width: columnWidths["amount"] ?? 110, alignment: .trailing)

            // Profit
            if let profit = pool.profit {
                Text(profit.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(profit >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                    .frame(width: columnWidths["profit"] ?? 110, alignment: .trailing)
            } else {
                // Show placeholder for completed pools
                let placeholder = pool.status == .completed ? 0.0.formattedAsLocalizedCurrency() : ""
                Text(placeholder)
                    .font(ResponsiveDesign.bodyFont())
                    .frame(width: columnWidths["profit"] ?? 110, alignment: .trailing)
            }

            // Return
            if let returnPercentage = pool.returnPercentage {
                Text("\(String(format: "%.0f", returnPercentage))%")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(returnPercentage >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                    .frame(width: columnWidths["return"] ?? 90, alignment: .trailing)
            } else {
                // Show placeholder for completed pools
                let placeholder = pool.status == .completed ? "0%" : ""
                Text(placeholder)
                    .font(ResponsiveDesign.bodyFont())
                    .frame(width: columnWidths["return"] ?? 90, alignment: .trailing)
            }

            // Beleg / Rechnung (Account Statement + Service Charge Invoice)
            InvestmentDocRefView(verrechnungNumber: pool.docNumber, rechnungNumber: pool.invoiceNumber)
                .frame(width: columnWidths["docRef"] ?? 100, alignment: .leading)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .padding(.vertical, ResponsiveDesign.spacing(6))
        .background(isEven ? AppTheme.screenBackground.opacity(0.3) : AppTheme.screenBackground.opacity(0.1))
    }

    private func totalRow(columnWidths: [String: CGFloat]) -> some View {
        HStack(spacing: tableColumnSpacing) {
            Text("Total")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)
                .frame(width: columnWidths["pot"] ?? 60, alignment: .leading)

            Text("")
                .frame(width: columnWidths["status"] ?? 80, alignment: .leading)

            Text(totalAmount.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)
                .frame(width: columnWidths["amount"] ?? 110, alignment: .trailing)

            if let profit = totalProfit {
                Text(profit.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
                    .frame(width: columnWidths["profit"] ?? 110, alignment: .trailing)
            } else {
                Text("not yet available")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .frame(width: columnWidths["profit"] ?? 110, alignment: .trailing)
            }

            if let returnPercentage = totalReturn {
                Text("\(String(format: "%.0f", returnPercentage))%")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .foregroundColor(returnPercentage >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                    .frame(width: columnWidths["return"] ?? 90, alignment: .trailing)
            } else {
                Text("not yet available")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .frame(width: columnWidths["return"] ?? 90, alignment: .trailing)
            }

            Text("")
                .frame(width: columnWidths["docRef"] ?? 100, alignment: .leading)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .padding(.vertical, ResponsiveDesign.spacing(6))
        .background(AppTheme.screenBackground.opacity(0.2))
    }
}
