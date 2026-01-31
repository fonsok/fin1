import Foundation

// MARK: - Address Verification Document Types

/// Types of documents accepted for address verification per KYC requirements
enum AddressVerificationDocumentType: String, CaseIterable, Codable, Hashable {
    case utilityBill           // Gas, electricity, water bill
    case bankStatement         // Official bank statement
    case governmentLetter      // Tax notice, official government correspondence
    case rentalAgreement       // Lease or rental contract
    case telephoneBill         // Landline or mobile phone bill
    case insuranceDocument     // Insurance policy document
    case officialRegistration  // Meldebestätigung (German registration certificate)

    var displayName: String {
        switch self {
        case .utilityBill: return "Utility Bill"
        case .bankStatement: return "Bank Statement"
        case .governmentLetter: return "Government Letter"
        case .rentalAgreement: return "Rental Agreement"
        case .telephoneBill: return "Telephone Bill"
        case .insuranceDocument: return "Insurance Document"
        case .officialRegistration: return "Official Registration Certificate"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .utilityBill: return "Versorgungsrechnung (Gas, Strom, Wasser)"
        case .bankStatement: return "Kontoauszug"
        case .governmentLetter: return "Behördliches Schreiben"
        case .rentalAgreement: return "Mietvertrag"
        case .telephoneBill: return "Telefonrechnung"
        case .insuranceDocument: return "Versicherungsdokument"
        case .officialRegistration: return "Meldebestätigung"
        }
    }

    var description: String {
        switch self {
        case .utilityBill:
            return "Recent utility bill (not older than 3 months) showing your name and new address"
        case .bankStatement:
            return "Official bank statement (not older than 3 months) showing your name and new address"
        case .governmentLetter:
            return "Official letter from a government authority showing your name and new address"
        case .rentalAgreement:
            return "Signed rental or lease agreement showing your name and new address"
        case .telephoneBill:
            return "Recent telephone bill showing your name and new address"
        case .insuranceDocument:
            return "Insurance policy or correspondence showing your name and new address"
        case .officialRegistration:
            return "Official registration certificate (Meldebestätigung) from local authorities"
        }
    }

    var icon: String {
        switch self {
        case .utilityBill: return "bolt.fill"
        case .bankStatement: return "building.columns.fill"
        case .governmentLetter: return "building.2.fill"
        case .rentalAgreement: return "house.fill"
        case .telephoneBill: return "phone.fill"
        case .insuranceDocument: return "shield.checkered"
        case .officialRegistration: return "checkmark.seal.fill"
        }
    }
}





