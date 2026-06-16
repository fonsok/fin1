import Foundation

// MARK: - P3c-3 Beleg EUR money (decode + display only)

/// EUR monetary value from server Beleg metadata. Decode-only on the client — no booking math.
struct BelegEURMoney: Codable, Equatable, Hashable, Sendable {
    let decimal: Decimal

    init(decimal: Decimal) {
        self.decimal = decimal
    }

    /// Cent-normalizes float literals (tests / previews).
    init(euro value: Double) {
        self.decimal = Self.decimalFromEURDouble(value)
    }

    init(euro value: Int) {
        self.decimal = Decimal(value)
    }

    init(cents value: Int) {
        self.decimal = Decimal(value) / 100
    }

    var doubleValue: Double {
        NSDecimalNumber(decimal: self.decimal).doubleValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            throw DecodingError.valueNotFound(
                BelegEURMoney.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "null EUR money")
            )
        }
        if let string = try? container.decode(String.self) {
            self.decimal = try Self.decimalFromEURString(string)
            return
        }
        if let intValue = try? container.decode(Int.self) {
            self.decimal = Decimal(intValue)
            return
        }
        if let doubleValue = try? container.decode(Double.self) {
            self.decimal = Self.decimalFromEURDouble(doubleValue)
            return
        }
        throw DecodingError.typeMismatch(
            BelegEURMoney.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "expected EUR number or string")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.doubleValue)
    }

    /// Prefer `amountCents` when P3c-2b dual-write is present on the parent object.
    static func resolving(cents: Int?, euro decoded: BelegEURMoney?) -> BelegEURMoney? {
        if let cents {
            return BelegEURMoney(cents: cents)
        }
        return decoded
    }

    static func decimalFromEURDouble(_ value: Double) -> Decimal {
        guard value.isFinite else { return .zero }
        let cents = Int64((value * 100).rounded())
        return Decimal(cents) / 100
    }

    static func decimalFromEURString(_ string: String) throws -> Decimal {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        guard let parsed = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "invalid EUR string: \(string)")
            )
        }
        return Self.decimalFromEURDouble(NSDecimalNumber(decimal: parsed).doubleValue)
    }
}
