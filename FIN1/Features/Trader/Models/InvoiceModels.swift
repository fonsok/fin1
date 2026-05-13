import Foundation

// MARK: - Invoice Item Model
struct InvoiceItem: Identifiable, Codable, Hashable {
    let id: String
    let description: String
    let quantity: Double
    let unitPrice: Double
    let totalAmount: Double
    let itemType: InvoiceItemType

    init(
        id: String = UUID().uuidString,
        description: String,
        quantity: Double,
        unitPrice: Double,
        itemType: InvoiceItemType
    ) {
        self.id = id
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalAmount = quantity * unitPrice
        self.itemType = itemType
    }
}

// MARK: - Customer Information Model
struct CustomerInfo: Codable, Hashable {
    var name: String
    var address: String
    var city: String
    var postalCode: String
    var taxNumber: String
    var depotNumber: String
    var bank: String
    var customerNumber: String
    var userId: String = ""

    var fullAddress: String {
        "\(self.address), \(self.postalCode) \(self.city)"
    }
}

// MARK: - CustomerInfo Extensions
extension CustomerInfo {
    /// Creates CustomerInfo from a User model
    /// - Parameter user: The user to convert
    /// - Returns: CustomerInfo with user's information, or default values if missing
    static func from(user: User) -> CustomerInfo {
        // Build full name with salutation and academic title
        var nameComponents: [String] = []
        if !user.academicTitle.isEmpty {
            nameComponents.append(user.academicTitle)
        }
        nameComponents.append(user.firstName)
        nameComponents.append(user.lastName)
        let fullName = nameComponents.joined(separator: " ")

        // Use user's address or default
        let address = user.streetAndNumber.isEmpty ? "Nicht angegeben" : user.streetAndNumber
        let city = user.city.isEmpty ? "Nicht angegeben" : user.city
        let postalCode = user.postalCode.isEmpty ? "00000" : user.postalCode
        let taxNumber = user.taxNumber.isEmpty ? "Nicht angegeben" : user.taxNumber

        // Generate a default depot number if not available (in real app, this would come from user's account)
        let depotNumber = "DE\(String(format: "%020d", abs(user.id.hashValue)))"

        // Default bank (in real app, this would come from user's account settings)
        let bank = LegalIdentity.bankName

        return CustomerInfo(
            name: fullName,
            address: address,
            city: city,
            postalCode: postalCode,
            taxNumber: taxNumber,
            depotNumber: depotNumber,
            bank: bank,
            customerNumber: user.customerNumber.isEmpty ? user.id : user.customerNumber,
            userId: user.id
        )
    }
}
