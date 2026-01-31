import Foundation

extension NumberFormatter {
    static var localizedNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        return formatter
    }()

    static var localizedIntegerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static var localizedDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static var localizedCurrencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    static var roiPercentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

extension Numeric {
    func formattedAsLocalizedNumber() -> String {
        return NumberFormatter.localizedNumberFormatter.string(for: self) ?? "\(self)"
    }

    func formattedAsLocalizedInteger() -> String {
        return NumberFormatter.localizedIntegerFormatter.string(for: self) ?? "\(self)"
    }

    func formattedAsLocalizedDecimal() -> String {
        return NumberFormatter.localizedDecimalFormatter.string(for: self) ?? "\(self)"
    }

    func formattedAsLocalizedCurrency() -> String {
        let formattedNumber = NumberFormatter.localizedCurrencyFormatter.string(for: self) ?? "\(self)"
        return "\(formattedNumber) €"
    }

    /// Formats a ROI/return percentage value with 2 decimal places and optional sign
    /// - Parameter includeSign: If true, adds "+" prefix for positive values
    /// - Returns: Formatted string like "+112.00%" or "-5.50%"
    func formattedAsROIPercentage(includeSign: Bool = true) -> String {
        // Convert to Double safely
        let doubleValue: Double
        switch self {
        case let value as Double:
            doubleValue = value
        case let value as Int:
            doubleValue = Double(value)
        case let value as Float:
            doubleValue = Double(value)
        case let value as CGFloat:
            doubleValue = Double(value)
        default:
            // Fallback: use string conversion
            if let nsNumber = self as? NSNumber {
                doubleValue = nsNumber.doubleValue
            } else {
                doubleValue = Double("\(self)") ?? 0.0
            }
        }

        let formattedNumber = NumberFormatter.roiPercentageFormatter.string(for: doubleValue) ?? String(format: "%.2f", doubleValue)
        let sign = includeSign && doubleValue > 0 ? "+" : ""
        return "\(sign)\(formattedNumber)%"
    }
}

extension Date.FormatStyle {
    static var localizedDate: Self {
        .init(date: .numeric, time: .omitted).locale(Locale(identifier: "de_DE"))
    }
}
