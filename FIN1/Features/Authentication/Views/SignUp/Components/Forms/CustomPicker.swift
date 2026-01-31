import SwiftUI

struct CustomPicker<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    let displayText: (T) -> String
    let labelColor: Color

    init(title: String, selection: Binding<T>, options: [T], displayText: @escaping (T) -> String, labelColor: Color = AppTheme.fontColor) {
        self.title = title
        self._selection = selection
        self.options = options
        self.displayText = displayText
        self.labelColor = labelColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(labelColor)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(action: { self.selection = option }, label: {
                        Text(displayText(option))
                            .foregroundColor(AppTheme.inputFieldText)
                    })
                }
            } label: {
                HStack {
                    Text(displayText(selection))
                        .foregroundColor(AppTheme.inputFieldText)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(AppTheme.inputFieldText)
                }
                .padding()
                .background(AppTheme.inputFieldBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
        }
    }
}

// MARK: - Convenience Initializers for Common Types

extension CustomPicker where T == Salutation {
    init(title: String, selection: Binding<Salutation>, labelColor: Color = AppTheme.fontColor) {
        self.init(
            title: title,
            selection: selection,
            options: Salutation.allCases,
            displayText: { $0.displayName },
            labelColor: labelColor
        )
    }
}

extension CustomPicker where T == EmploymentStatus {
    init(title: String, selection: Binding<EmploymentStatus>) {
        self.init(
            title: title,
            selection: selection,
            options: EmploymentStatus.allCases,
            displayText: { $0.displayName }
        )
    }
}

extension CustomPicker where T == IncomeRange {
    init(title: String, selection: Binding<IncomeRange>) {
        self.init(
            title: title,
            selection: selection,
            options: IncomeRange.allCases,
            displayText: { $0.displayName }
        )
    }
}

extension CustomPicker where T == CashAndLiquidAssets {
    init(title: String, selection: Binding<CashAndLiquidAssets>) {
        self.init(
            title: title,
            selection: selection,
            options: CashAndLiquidAssets.allCases,
            displayText: { $0.displayName }
        )
    }
}

// MARK: - Investment Experience Extensions

extension CustomPicker where T == StocksTransactionCount {
    init(title: String, selection: Binding<StocksTransactionCount>) {
        self.init(
            title: title,
            selection: selection,
            options: StocksTransactionCount.allCases,
            displayText: { $0.displayName }
        )
    }
}

extension CustomPicker where T == ETFsTransactionCount {
    init(title: String, selection: Binding<ETFsTransactionCount>) {
        self.init(
            title: title,
            selection: selection,
            options: ETFsTransactionCount.allCases,
            displayText: { $0.displayName }
        )
    }
}

extension CustomPicker where T == DerivativesTransactionCount {
    init(title: String, selection: Binding<DerivativesTransactionCount>) {
        self.init(
            title: title,
            selection: selection,
            options: DerivativesTransactionCount.allCases,
            displayText: { $0.displayName }
        )
    }
}

extension CustomPicker where T == InvestmentAmount {
    init(title: String, selection: Binding<InvestmentAmount>) {
        self.init(
            title: title,
            selection: selection,
            options: InvestmentAmount.allCases,
            displayText: { $0.displayName }
        )
    }
}

extension CustomPicker where T == DerivativesInvestmentAmount {
    init(title: String, selection: Binding<DerivativesInvestmentAmount>) {
        self.init(
            title: title,
            selection: selection,
            options: DerivativesInvestmentAmount.allCases,
            displayText: { $0.displayName }
        )
    }
}

extension CustomPicker where T == HoldingPeriod {
    init(title: String, selection: Binding<HoldingPeriod>) {
        self.init(
            title: title,
            selection: selection,
            options: HoldingPeriod.allCases,
            displayText: { $0.displayName }
        )
    }
}

// MARK: - Integer-based Experience Pickers

struct ExperiencePicker: View {
    let title: String
    @Binding var selection: Int
    let options: [(Int, String)]

    init(title: String, selection: Binding<Int>, options: [(Int, String)]) {
        self.title = title
        self._selection = selection
        self.options = options
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            Menu {
                ForEach(options, id: \.0) { option in
                    Button(action: { self.selection = option.0 }, label: {
                        Text(option.1)
                            .foregroundColor(AppTheme.inputFieldText)
                    })
                }
            } label: {
                HStack {
                    Text(getDisplayText())
                        .foregroundColor(AppTheme.inputFieldText)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(AppTheme.inputFieldText)
                }
                .padding()
                .background(AppTheme.inputFieldBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
        }
    }

    private func getDisplayText() -> String {
        return options.first { $0.0 == selection }?.1 ?? options.first?.1 ?? ""
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: ResponsiveDesign.spacing(20)) {
        CustomPicker(
            title: "Salutation",
            selection: .constant(.mr)
        )

        CustomPicker(
            title: "Employment Status",
            selection: .constant(.employed)
        )

        CustomPicker(
            title: "Income Range",
            selection: .constant(.middle)
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
}
