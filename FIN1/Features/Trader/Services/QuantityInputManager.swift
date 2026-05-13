import Combine
import Foundation

// MARK: - Quantity Input Manager Protocol
protocol QuantityInputManagerProtocol {
    var quantity: Double { get set }
    var quantityText: String { get set }
    var showMaxValueWarning: Bool { get set }

    func processQuantityText(_ text: String) -> Double
    func setupQuantityTextBinding() -> AnyCancellable
    func setupQuantityBinding() -> AnyCancellable
}

// MARK: - Quantity Input Manager
/// Manages quantity input processing, validation, and formatting
@MainActor
final class QuantityInputManager: ObservableObject {
    @Published var quantity: Double = 1_000
    @Published var quantityText: String = "1.000"
    @Published var showMaxValueWarning: Bool = false

    private let maxQuantity: Int = 10_000_000
    private var cancellables = Set<AnyCancellable>()

    init(initialQuantity: Double = 1_000) {
        self.quantity = initialQuantity
        self.quantityText = Int(initialQuantity).formattedAsLocalizedInteger()
    }

    // MARK: - Public Methods

    func processQuantityText(_ text: String) -> Double {
        // Convert German formatted text to Double
        let cleanText = text.replacingOccurrences(of: ".", with: "")
        let value = Double(cleanText) ?? 0.0

        // Validate and correct if exceeds maximum
        if value > Double(self.maxQuantity) {
            self.handleMaxValueExceeded()
            return value // Return the actual entered value to show the warning
        } else {
            self.hideMaxValueWarning()
        }

        return value
    }

    func setupQuantityTextBinding() -> AnyCancellable {
        self.$quantityText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .map { [weak self] text in
                guard let self = self else { return 0.0 }
                return self.processQuantityText(text)
            }
            .sink { [weak self] value in
                self?.quantity = value
            }
            .store(in: &self.cancellables)

        // Return a cancellable that can be used to cancel all subscriptions
        return AnyCancellable {
            // This will be handled by the cancellables set
        }
    }

    func setupQuantityBinding() -> AnyCancellable {
        self.$quantity
            .map { value in
                let formatter = NumberFormatter.localizedIntegerFormatter
                return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
            }
            .sink { [weak self] value in
                self?.quantityText = value
            }
            .store(in: &self.cancellables)

        return AnyCancellable {
            // This will be handled by the cancellables set
        }
    }

    var exceedsMaximum: Bool {
        return self.quantity > Double(self.maxQuantity)
    }

    func cleanup() {
        self.cancellables.removeAll()
    }

    // MARK: - Private Methods

    private func handleMaxValueExceeded() {
        self.showMaxValueWarning = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.quantityText = self.maxQuantity.formattedAsLocalizedInteger()
            self.showMaxValueWarning = false
        }
    }

    private func hideMaxValueWarning() {
        self.showMaxValueWarning = false
    }
}
