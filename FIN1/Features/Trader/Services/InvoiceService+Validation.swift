import Foundation

extension InvoiceService {

    func validateInvoice(_ invoice: Invoice) -> Bool {
        guard !invoice.invoiceNumber.isEmpty,
              !invoice.customerInfo.name.isEmpty,
              !invoice.items.isEmpty else {
            return false
        }

        guard invoice.totalAmount > 0 else {
            return false
        }

        for item in invoice.items {
            guard item.quantity > 0,
                  item.unitPrice >= 0,
                  item.totalAmount >= 0 else {
                return false
            }
        }

        return true
    }

    func validateCustomerInfo(_ customerInfo: CustomerInfo) -> Bool {
        guard !customerInfo.name.isEmpty,
              !customerInfo.address.isEmpty,
              !customerInfo.city.isEmpty,
              !customerInfo.postalCode.isEmpty,
              !customerInfo.taxNumber.isEmpty,
              !customerInfo.depotNumber.isEmpty,
              !customerInfo.bank.isEmpty,
              !customerInfo.customerNumber.isEmpty else {
            return false
        }

        let postalCodeRegex = "^[0-9]{5}$"
        let postalCodePredicate = NSPredicate(format: "SELF MATCHES %@", postalCodeRegex)
        guard postalCodePredicate.evaluate(with: customerInfo.postalCode) else {
            return false
        }

        return true
    }
}
